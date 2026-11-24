public with sharing class SmartGoalBulkUploadController {

    // ─── Inner types ────────────────────────────────────────────────────────

    public class ParsedGoalRow {
        public String employeeEmail;
        public String employeeName;   // used when file has names instead of emails
        public String goalName;
        public String goalDescription;
        public String metric;
        public Decimal weightPercentage;
        public String startDate;
        public String endDate;
        // Stage fields (optional — blank means no stage on this row)
        public String stageName;
        public String stageDescription;
        public Integer stageStepNumber;
        public String stageStartDate;
        public String stageEndDate;
        // Per-goal stage names from CSV columns (index 0=month1 … 11=month12; blank = auto-generate)
        public List<String> stageNames;
    }

    public class PreviewEmployee {
        @AuraEnabled public String email;
        @AuraEnabled public String name;
        @AuraEnabled public String action;      // 'new' | 'copy' | 'warn'
        @AuraEnabled public Integer goalCount;
        @AuraEnabled public Integer stageCount;
        @AuraEnabled public String warning;
        @AuraEnabled public Boolean planExists;
    }

    public class PreviewResult {
        @AuraEnabled public List<PreviewEmployee> employees = new List<PreviewEmployee>();
        @AuraEnabled public Integer newEmployeeCount  = 0;
        @AuraEnabled public Integer copyEmployeeCount = 0;
        @AuraEnabled public Integer newGoalCount      = 0;
        @AuraEnabled public Integer newStageCount     = 0;
        @AuraEnabled public Integer copiedGoalCount   = 0;
        @AuraEnabled public Integer plansToCreate     = 0;
        @AuraEnabled public Integer warningCount      = 0;
    }

    public class ExecuteResult {
        @AuraEnabled public Boolean success         = true;
        @AuraEnabled public Integer plansCreated    = 0;
        @AuraEnabled public Integer goalsCreated    = 0;
        @AuraEnabled public Integer initiativesCreated = 0;
        @AuraEnabled public Integer stagesCreated   = 0;
        @AuraEnabled public Integer goalsCopied     = 0;
        @AuraEnabled public List<String> errors     = new List<String>();
    }

    // ─── Picklist helper ────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<String> getFiscalYears() {
        List<String> years = new List<String>();
        for (Schema.PicklistEntry e : Annual_Plan__c.Fiscal_Year__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) years.add(e.getValue());
        }
        return years;
    }

    // ─── Preview ────────────────────────────────────────────────────────────

    @AuraEnabled
    public static PreviewResult previewUpload(String jsonRows, String targetFY, String sourceFY) {
        List<ParsedGoalRow> rows = parseRows(jsonRows);
        List<Map<String, Employee__c>> empMaps = buildEmployeeMaps();
        Map<String, Employee__c> emailToEmp  = empMaps[0];
        Map<String, Employee__c> nameToEmp   = empMaps[1];
        Map<Id, Annual_Plan__c>  empToSrcPlan = getAnnualPlans(sourceFY);
        Map<Id, List<SMART_Goal__c>> planToSrcGoals = getSmartGoalsByPlan(empToSrcPlan.values());
        Map<Id, Annual_Plan__c>  empToTgtPlan = getAnnualPlans(targetFY);

        Map<String, Map<String, List<ParsedGoalRow>>> csvMap = groupRowsByKey(rows);
        Map<String, Employee__c> csvKeyToEmp = resolveCsvEmployees(csvMap.keySet(), emailToEmp, nameToEmp);

        // Track which employee Ids came from the CSV so copy-forward can skip them
        Set<Id> csvEmpIds = new Set<Id>();
        for (Employee__c e : csvKeyToEmp.values()) {
            if (e != null) csvEmpIds.add(e.Id);
        }

        PreviewResult result = new PreviewResult();

        // Employees listed in the CSV — new goals
        for (String key : csvMap.keySet()) {
            PreviewEmployee pe = new PreviewEmployee();
            pe.action     = 'new';
            pe.goalCount  = csvMap.get(key).size();
            // Each goal gets 12 monthly stages (auto-generated or from CSV columns)
            pe.stageCount = pe.goalCount * 12;

            Employee__c emp = csvKeyToEmp.get(key);
            if (emp == null) {
                pe.email   = key;
                pe.name    = '(not found in system)';
                pe.action  = 'warn';
                pe.warning = 'No active Employee record found for: ' + key;
                result.warningCount++;
            } else {
                pe.email      = emp.User__r.Email;
                pe.name       = emp.Name;
                pe.planExists = empToTgtPlan.containsKey(emp.Id);
                if (!pe.planExists) result.plansToCreate++;
                result.newGoalCount  += pe.goalCount;
                result.newStageCount += pe.stageCount;
                result.newEmployeeCount++;
            }
            result.employees.add(pe);
        }

        // Employees NOT in the CSV — copy from source year
        for (String email : emailToEmp.keySet()) {
            Employee__c emp = emailToEmp.get(email);
            if (csvEmpIds.contains(emp.Id)) continue;
            Annual_Plan__c srcPlan = empToSrcPlan.get(emp.Id);
            if (srcPlan == null) continue;
            List<SMART_Goal__c> srcGoals = planToSrcGoals.get(srcPlan.Id);
            if (srcGoals == null || srcGoals.isEmpty()) continue;

            PreviewEmployee pe = new PreviewEmployee();
            pe.email      = email;
            pe.name       = emp.Name;
            pe.action     = 'copy';
            pe.goalCount  = srcGoals.size();
            pe.stageCount = 0;
            pe.planExists = empToTgtPlan.containsKey(emp.Id);
            if (!pe.planExists) result.plansToCreate++;
            result.copiedGoalCount   += srcGoals.size();
            result.copyEmployeeCount++;
            result.employees.add(pe);
        }

        return result;
    }

    // ─── Execute ────────────────────────────────────────────────────────────

    @AuraEnabled
    public static ExecuteResult executeUpload(String jsonRows, String targetFY, String sourceFY) {
        ExecuteResult result = new ExecuteResult();
        try {
            List<ParsedGoalRow> rows = parseRows(jsonRows);
            List<Map<String, Employee__c>> empMaps = buildEmployeeMaps();
            Map<String, Employee__c> emailToEmp  = empMaps[0];
            Map<String, Employee__c> nameToEmp   = empMaps[1];
            Map<Id, Annual_Plan__c>  empToSrcPlan = getAnnualPlans(sourceFY);
            Map<Id, List<SMART_Goal__c>> planToSrcGoals = getSmartGoalsByPlan(empToSrcPlan.values());
            Map<Id, Annual_Plan__c>  empToTgtPlan = getAnnualPlans(targetFY);
            Map<Id, List<SMART_Goal__c>> planToTgtGoals = getSmartGoalsByPlan(empToTgtPlan.values());

            Map<String, Map<String, List<ParsedGoalRow>>> csvMap = groupRowsByKey(rows);
            Map<String, Employee__c> csvKeyToEmp = resolveCsvEmployees(csvMap.keySet(), emailToEmp, nameToEmp);

            Set<Id> csvEmpIds = new Set<Id>();
            for (Employee__c e : csvKeyToEmp.values()) {
                if (e != null) csvEmpIds.add(e.Id);
            }

            // ── Step 1: Create missing Annual Plans ──────────────────────────
            List<Annual_Plan__c> plansToInsert = new List<Annual_Plan__c>();

            for (String key : csvMap.keySet()) {
                Employee__c emp = csvKeyToEmp.get(key);
                if (emp == null || empToTgtPlan.containsKey(emp.Id)) continue;
                plansToInsert.add(buildNewPlan(emp, targetFY, empToSrcPlan.get(emp.Id)));
            }
            for (String email : emailToEmp.keySet()) {
                Employee__c emp = emailToEmp.get(email);
                if (csvEmpIds.contains(emp.Id)) continue;
                if (empToTgtPlan.containsKey(emp.Id)) continue;
                Annual_Plan__c srcPlan = empToSrcPlan.get(emp.Id);
                if (srcPlan == null) continue;
                List<SMART_Goal__c> srcGoals = planToSrcGoals.get(srcPlan.Id);
                if (srcGoals == null || srcGoals.isEmpty()) continue;
                plansToInsert.add(buildNewPlan(emp, targetFY, srcPlan));
            }
            if (!plansToInsert.isEmpty()) {
                insert plansToInsert;
                result.plansCreated = plansToInsert.size();
                for (Annual_Plan__c p : plansToInsert) {
                    empToTgtPlan.put(p.Employee__c, p);
                }
            }

            // ── Step 2: Create new SMART Goals from CSV (one per unique goal) ─
            List<SMART_Goal__c> goalsToInsert = new List<SMART_Goal__c>();
            List<String> goalInsertKeys = new List<String>(); // 'empKey|goalName'

            for (String key : csvMap.keySet()) {
                Employee__c emp = csvKeyToEmp.get(key);
                if (emp == null) continue;
                Annual_Plan__c plan = empToTgtPlan.get(emp.Id);
                if (plan == null) continue;
                for (String goalName : csvMap.get(key).keySet()) {
                    ParsedGoalRow firstRow = csvMap.get(key).get(goalName)[0];
                    goalsToInsert.add(buildGoalFromRow(firstRow, plan.Id));
                    goalInsertKeys.add(key + '|' + goalName);
                }
            }
            if (!goalsToInsert.isEmpty()) {
                insert goalsToInsert;
                result.goalsCreated = goalsToInsert.size();
            }

            // ── Step 3: Create an Initiative per new goal ────────────────────
            // Stages reference the Initiative on their layout, so each goal needs
            // a matching Initiative record for the fiscal year.
            List<Initiative__c> initiativesToInsert = new List<Initiative__c>();
            for (Integer i = 0; i < goalsToInsert.size(); i++) {
                String empKey = goalInsertKeys[i].substringBefore('|');
                String gName  = goalInsertKeys[i].substringAfter('|');
                Employee__c empRec = csvKeyToEmp.get(empKey);
                initiativesToInsert.add(new Initiative__c(
                    Initiative_Name__c = gName,
                    Employee__c        = empRec != null ? empRec.Id : null,
                    Fiscal_Year__c     = targetFY,
                    Start_Date__c      = fiscalYearStart(targetFY),
                    End_Date__c        = fiscalYearEnd(targetFY),
                    Status__c          = 'In Progress'
                ));
            }
            if (!initiativesToInsert.isEmpty()) {
                insert initiativesToInsert;
                result.initiativesCreated = initiativesToInsert.size();
            }

            // ── Step 4: Create Initiative Stages for new goals ───────────────
            List<Initiative_Stage__c> stagesToInsert = new List<Initiative_Stage__c>();
            for (Integer i = 0; i < goalsToInsert.size(); i++) {
                String insertKey = goalInsertKeys[i];
                String empKey = insertKey.substringBefore('|');
                String gName  = insertKey.substringAfter('|');
                Id goalId     = goalsToInsert[i].Id;
                Id initiativeId = initiativesToInsert[i].Id;
                Employee__c empRec = csvKeyToEmp.get(empKey);
                Id empId = empRec != null ? empRec.Id : null;

                // Collect per-month stage names from the first CSV row for this goal
                List<String> csvStageNames = new List<String>();
                List<ParsedGoalRow> goalRows = csvMap.get(empKey).get(gName);
                if (!goalRows.isEmpty() && goalRows[0].stageNames != null) {
                    csvStageNames = goalRows[0].stageNames;
                }

                Id ownerUserId = empRec != null ? empRec.User__c : null;

                // Also handle the old row-per-stage format (Stage_Name on individual rows)
                Boolean hasRowStages = false;
                for (ParsedGoalRow r : goalRows) {
                    if (String.isNotBlank(r.stageName)) {
                        stagesToInsert.add(buildStageFromRow(r, goalId, initiativeId, empId, ownerUserId, targetFY));
                        hasRowStages = true;
                    }
                }

                // If no row-based stages, auto-generate 12 monthly stages
                if (!hasRowStages) {
                    stagesToInsert.addAll(buildMonthlyStages(goalId, initiativeId, empId, ownerUserId, targetFY,
                        gName, csvStageNames));
                }
            }
            if (!stagesToInsert.isEmpty()) {
                insert stagesToInsert;
                result.stagesCreated = stagesToInsert.size();
            }

            // ── Step 5: Clone SMART Goals for non-CSV employees ──────────────
            List<SMART_Goal__c> goalsToCopy = new List<SMART_Goal__c>();
            for (String email : emailToEmp.keySet()) {
                Employee__c emp = emailToEmp.get(email);
                if (csvEmpIds.contains(emp.Id)) continue;
                Annual_Plan__c srcPlan = empToSrcPlan.get(emp.Id);
                if (srcPlan == null) continue;
                List<SMART_Goal__c> srcGoals = planToSrcGoals.get(srcPlan.Id);
                if (srcGoals == null || srcGoals.isEmpty()) continue;
                Annual_Plan__c tgtPlan = empToTgtPlan.get(emp.Id);
                if (tgtPlan == null) continue;
                // Never copy over a plan that already has goals, so re-running an
                // upload cannot duplicate what a previous run created.
                List<SMART_Goal__c> tgtGoals = planToTgtGoals.get(tgtPlan.Id);
                if (tgtGoals != null && !tgtGoals.isEmpty()) continue;
                for (SMART_Goal__c sg : srcGoals) {
                    goalsToCopy.add(cloneGoal(sg, tgtPlan.Id));
                }
            }
            if (!goalsToCopy.isEmpty()) {
                insert goalsToCopy;
                result.goalsCopied = goalsToCopy.size();
            }

        } catch (Exception e) {
            result.success = false;
            result.errors.add(e.getMessage());
        }
        return result;
    }

    // ─── Private helpers ────────────────────────────────────────────────────

    private static List<ParsedGoalRow> parseRows(String jsonRows) {
        List<Object> raw = (List<Object>) JSON.deserializeUntyped(jsonRows);
        List<ParsedGoalRow> rows = new List<ParsedGoalRow>();
        for (Object o : raw) {
            Map<String, Object> m = (Map<String, Object>) o;
            ParsedGoalRow r   = new ParsedGoalRow();
            r.employeeEmail   = strVal(m, 'Employee_Email');
            r.employeeName    = strVal(m, 'Employee_Name');
            r.goalName        = strVal(m, 'Goal_Name');
            r.goalDescription = strVal(m, 'Goal_Description');
            r.metric          = strVal(m, 'Metric');
            r.startDate       = coalesce(strVal(m, 'Goal_Start_Date'), strVal(m, 'Start_Date'));
            r.endDate         = coalesce(strVal(m, 'Goal_End_Date'),   strVal(m, 'End_Date'));
            Object w = m.get('Weight_Percentage');
            if (w != null) {
                try { r.weightPercentage = Decimal.valueOf(String.valueOf(w)); } catch (Exception e) {}
            }
            r.stageName        = strVal(m, 'Stage_Name');
            r.stageDescription = strVal(m, 'Stage_Description');
            r.stageStartDate   = strVal(m, 'Stage_Start_Date');
            r.stageEndDate     = strVal(m, 'Stage_End_Date');
            Object sn = m.get('Stage_Step_Number');
            if (sn != null && String.isNotBlank(String.valueOf(sn))) {
                try { r.stageStepNumber = Integer.valueOf(String.valueOf(sn)); } catch (Exception e) {}
            }
            r.stageNames = new List<String>();
            for (Integer si = 1; si <= 12; si++) {
                r.stageNames.add(coalesce(strVal(m, 'Stage_' + si), ''));
            }
            rows.add(r);
        }
        return rows;
    }

    // Returns the effective lookup key for a row: email if present, else name
    private static String getRowKey(ParsedGoalRow r) {
        if (String.isNotBlank(r.employeeEmail)) return r.employeeEmail.toLowerCase();
        if (String.isNotBlank(r.employeeName))  return r.employeeName.toLowerCase();
        return null;
    }

    // Groups rows by effective employee key then by goal name
    private static Map<String, Map<String, List<ParsedGoalRow>>> groupRowsByKey(List<ParsedGoalRow> rows) {
        Map<String, Map<String, List<ParsedGoalRow>>> result = new Map<String, Map<String, List<ParsedGoalRow>>>();
        for (ParsedGoalRow r : rows) {
            String empKey = getRowKey(r);
            if (empKey == null || String.isBlank(r.goalName)) continue;
            String goalKey = r.goalName.toLowerCase();
            if (!result.containsKey(empKey)) result.put(empKey, new Map<String, List<ParsedGoalRow>>());
            if (!result.get(empKey).containsKey(goalKey)) result.get(empKey).put(goalKey, new List<ParsedGoalRow>());
            result.get(empKey).get(goalKey).add(r);
        }
        return result;
    }

    // Builds email→emp and name→emp lookup maps in a single SOQL query
    private static List<Map<String, Employee__c>> buildEmployeeMaps() {
        Map<String, Employee__c> byEmail = new Map<String, Employee__c>();
        Map<String, Employee__c> byName  = new Map<String, Employee__c>();
        List<Employee__c> emps = [
            SELECT Id, Name, User__c, User__r.Email, User__r.Name, Manager__c
            FROM Employee__c
            WHERE Active__c = true AND User__c != null
        ];
        for (Employee__c e : emps) {
            if (String.isNotBlank(e.User__r.Email)) byEmail.put(e.User__r.Email.toLowerCase(), e);
            if (String.isNotBlank(e.User__r.Name))  byName.put(e.User__r.Name.toLowerCase(), e);
        }
        // A CSV may identify people by their Employee record name rather than their
        // User name, and the two differ for some staff. Index those too, without
        // letting them displace a User name match.
        for (Employee__c e : emps) {
            if (String.isBlank(e.Name)) continue;
            String nameKey = e.Name.toLowerCase();
            if (!byName.containsKey(nameKey)) byName.put(nameKey, e);
        }
        return new List<Map<String, Employee__c>>{ byEmail, byName };
    }

    // Resolves CSV keys (email-or-name) to Employee__c records
    private static Map<String, Employee__c> resolveCsvEmployees(
        Set<String> csvKeys,
        Map<String, Employee__c> byEmail,
        Map<String, Employee__c> byName
    ) {
        Map<String, Employee__c> result = new Map<String, Employee__c>();
        for (String key : csvKeys) {
            Employee__c emp = byEmail.containsKey(key) ? byEmail.get(key) : byName.get(key);
            result.put(key, emp);
        }
        return result;
    }

    private static String strVal(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return v != null ? String.valueOf(v).trim() : null;
    }

    private static String coalesce(String a, String b) {
        return String.isNotBlank(a) ? a : b;
    }

    private static Map<Id, Annual_Plan__c> getAnnualPlans(String fiscalYear) {
        Map<Id, Annual_Plan__c> result = new Map<Id, Annual_Plan__c>();
        for (Annual_Plan__c p : [
            SELECT Id, Employee__c, Manager__c
            FROM Annual_Plan__c
            WHERE Fiscal_Year__c = :fiscalYear AND Employee__c != null
        ]) {
            result.put(p.Employee__c, p);
        }
        return result;
    }

    private static Map<Id, List<SMART_Goal__c>> getSmartGoalsByPlan(List<Annual_Plan__c> plans) {
        Set<Id> planIds = new Set<Id>();
        for (Annual_Plan__c p : plans) planIds.add(p.Id);
        Map<Id, List<SMART_Goal__c>> result = new Map<Id, List<SMART_Goal__c>>();
        if (planIds.isEmpty()) return result;
        for (SMART_Goal__c g : [
            SELECT Id, Annual_Plan__c, Smart_Goal__c, Initiative_Name__c,
                   Metric__c, Percentage__c, Start_Date__c, End_Date__c
            FROM SMART_Goal__c
            WHERE Annual_Plan__c IN :planIds
        ]) {
            if (!result.containsKey(g.Annual_Plan__c)) result.put(g.Annual_Plan__c, new List<SMART_Goal__c>());
            result.get(g.Annual_Plan__c).add(g);
        }
        return result;
    }

    private static Annual_Plan__c buildNewPlan(Employee__c emp, String fiscalYear, Annual_Plan__c srcPlan) {
        Annual_Plan__c p = new Annual_Plan__c(
            Name           = emp.User__r.Name + ' | ' + fiscalYear,
            OwnerId        = emp.User__c,
            Employee__c    = emp.Id,
            Fiscal_Year__c = fiscalYear,
            Stage__c       = 'Manager Review'
        );
        if (srcPlan != null && srcPlan.Manager__c != null) p.Manager__c = srcPlan.Manager__c;
        return p;
    }

    private static SMART_Goal__c buildGoalFromRow(ParsedGoalRow r, Id planId) {
        SMART_Goal__c g = new SMART_Goal__c(
            Annual_Plan__c     = planId,
            Initiative_Name__c = r.goalName,
            Smart_Goal__c      = r.goalDescription,
            Metric__c          = r.metric,
            Percentage__c      = r.weightPercentage
        );
        if (String.isNotBlank(r.startDate)) {
            try { g.Start_Date__c = Date.parse(r.startDate); } catch (Exception e) {}
        }
        if (String.isNotBlank(r.endDate)) {
            try { g.End_Date__c = Date.parse(r.endDate); } catch (Exception e) {}
        }
        return g;
    }

    private static Initiative_Stage__c buildStageFromRow(
        ParsedGoalRow r, Id smartGoalId, Id initiativeId, Id employeeId, Id ownerId, String fiscalYear
    ) {
        Initiative_Stage__c s = new Initiative_Stage__c(
            Name                          = r.stageName,
            SMART_Goal__c                 = smartGoalId,
            Initiative__c                 = initiativeId,
            Employee__c                   = employeeId,
            Fiscal_Year__c                = fiscalYear,
            Requires_Approval__c          = true,
            Initiative_Stage_Hierarchy__c = 'Parent Stage',
            Stage_Description__c          = r.stageDescription,
            Stage_Step_Number__c          = r.stageStepNumber
        );
        if (ownerId != null) s.OwnerId = ownerId;
        if (String.isNotBlank(r.stageStartDate)) {
            try { s.Start_Date__c = Date.parse(r.stageStartDate); } catch (Exception e) {}
        }
        if (String.isNotBlank(r.stageEndDate)) {
            try { s.End_Date__c = Date.parse(r.stageEndDate); } catch (Exception e) {}
        }
        return s;
    }

    // fiscalYear format: "October YYYY - September YYYY"
    private static Integer fiscalYearStartYear(String fiscalYear) {
        if (String.isBlank(fiscalYear)) return null;
        try {
            return Integer.valueOf(fiscalYear.substringAfter('October ').substringBefore(' -').trim());
        } catch (Exception e) { return null; }
    }

    private static Date fiscalYearStart(String fiscalYear) {
        Integer y = fiscalYearStartYear(fiscalYear);
        return y == null ? null : Date.newInstance(y, 10, 1);
    }

    private static Date fiscalYearEnd(String fiscalYear) {
        Integer y = fiscalYearStartYear(fiscalYear);
        return y == null ? null : Date.newInstance(y + 1, 9, 30);
    }

    private static SMART_Goal__c cloneGoal(SMART_Goal__c src, Id newPlanId) {
        return new SMART_Goal__c(
            Annual_Plan__c     = newPlanId,
            Initiative_Name__c = src.Initiative_Name__c,
            Smart_Goal__c      = src.Smart_Goal__c,
            Metric__c          = src.Metric__c,
            Percentage__c      = src.Percentage__c,
            Start_Date__c      = src.Start_Date__c,
            End_Date__c        = src.End_Date__c
        );
    }

    // Builds 12 monthly Initiative Stages for a newly-created SMART Goal.
    // csvStageNames: up to 12 entries from the CSV (blank = auto-generate from goalName).
    // fiscalYear format: "October YYYY - September YYYY"
    private static List<Initiative_Stage__c> buildMonthlyStages(
        Id smartGoalId, Id initiativeId, Id employeeId, Id ownerId, String fiscalYear,
        String goalName, List<String> csvStageNames
    ) {
        List<Initiative_Stage__c> stages = new List<Initiative_Stage__c>();
        if (String.isBlank(fiscalYear)) return stages;

        // Parse start year from "October YYYY - ..."
        Integer startYear;
        try {
            startYear = Integer.valueOf(fiscalYear.substringAfter('October ').substringBefore(' -').trim());
        } catch (Exception e) { return stages; }

        String[] monthLabels = new String[]{
            'Oct ' + startYear,  'Nov ' + startYear,  'Dec ' + startYear,
            'Jan ' + (startYear+1), 'Feb ' + (startYear+1), 'Mar ' + (startYear+1),
            'Apr ' + (startYear+1), 'May ' + (startYear+1), 'Jun ' + (startYear+1),
            'Jul ' + (startYear+1), 'Aug ' + (startYear+1), 'Sep ' + (startYear+1)
        };
        Integer[] monthNums  = new Integer[]{ 10,11,12, 1,2,3, 4,5,6, 7,8,9 };
        Integer[] yearNums   = new Integer[]{
            startYear,startYear,startYear,
            startYear+1,startYear+1,startYear+1,
            startYear+1,startYear+1,startYear+1,
            startYear+1,startYear+1,startYear+1
        };

        String safeGoalName = String.isNotBlank(goalName) && goalName.length() > 69
            ? goalName.left(69) : goalName;

        for (Integer i = 0; i < 12; i++) {
            String csvName = (csvStageNames != null && csvStageNames.size() > i)
                ? csvStageNames[i] : '';
            String stageName = String.isNotBlank(csvName)
                ? csvName
                : (safeGoalName + ' - ' + monthLabels[i]);
            // Enforce 80-char limit
            if (stageName.length() > 80) stageName = stageName.left(80);

            Initiative_Stage__c s = new Initiative_Stage__c(
                Name                          = stageName,
                SMART_Goal__c                 = smartGoalId,
                Initiative__c                 = initiativeId,
                Employee__c                   = employeeId,
                Fiscal_Year__c                = fiscalYear,
                Start_Date__c                 = Date.newInstance(yearNums[i], monthNums[i], 1),
                Stage_Step_Number__c          = i + 1,
                Requires_Approval__c          = true,
                Initiative_Stage_Hierarchy__c = 'Parent Stage'
            );
            if (ownerId != null) s.OwnerId = ownerId;
            stages.add(s);
        }
        return stages;
    }
}

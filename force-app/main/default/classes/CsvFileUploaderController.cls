/**
 * @description       : This class is the Controller for the File Uploader Lwc
 * @author            : Pablo Castro 09-02-2025
 * @group             : 
 * @last modified on  : 09-18-2025
 * @last modified by  : Pablo Castro
**/

public with sharing class CsvFileUploaderController {

    @AuraEnabled
    public static Map<String, Object> createBenefits(String jsonRows) {
        List<PBIDataWrapper> deathReportRecords = (List<PBIDataWrapper>) JSON.deserialize(jsonRows, List<PBIDataWrapper>.class);
        Map<String, Object> result = new Map<String, Object>();
        Set<String> listOfPIDs = new Set<String>();
        for (PBIDataWrapper deathReport : deathReportRecords) {
            if (String.isNotBlank(deathReport.clientPID)) {
                listOfPIDs.add(deathReport.clientPID);
            }
        }

        List<Contact> relatedContactMembers = new List<Contact>();
        relatedContactMembers = [SELECT Id, FirstName, LastName, Member_SSN__c, PID__c FROM Contact WHERE PID__c IN :listOfPIDs];
        Map<String, Contact> relatedContactRecordsMap = new Map<String, Contact>();
        for (Contact relatedContactRecord : relatedContactMembers) {
            relatedContactRecordsMap.put(relatedContactRecord.PID__c, relatedContactRecord);
        }

        List<Benefit__c> relatedBenefitRecords = new List<Benefit__c>();
        relatedBenefitRecords = [SELECT Id, Member__c, Benefit_Type__c FROM Benefit__c WHERE Member__c IN :relatedContactMembers];
        Map<String, List<Benefit__c>> relatedBenefitRecordsMap = new Map<String, List<Benefit__c>>();
        for (Benefit__c benefitRecord : relatedBenefitRecords) {
            if (!relatedBenefitRecordsMap.containsKey(benefitRecord.Member__c)) {
                relatedBenefitRecordsMap.put(benefitRecord.Member__c, new List<Benefit__c>());
            }
            relatedBenefitRecordsMap.get(benefitRecord.Member__c).add(benefitRecord);
        }

        List<Benefit__c> newBenefitRecords = new List<Benefit__c>();
        for (PBIDataWrapper deathReport : deathReportRecords) {
            String benefitType = deathReport.benefitType;
            Contact relatedContact = new Contact();
            relatedContact = relatedContactRecordsMap.get(deathReport.clientPID);
            List<Benefit__c> relatedBenefits = new List<Benefit__c>();
            if (relatedBenefitRecordsMap.containsKey(relatedContact.Id)) {
                relatedBenefits = relatedBenefitRecordsMap.get(relatedContact.Id);
            }

            if (relatedBenefits.size() == 0 || relatedBenefits.size() == 1 && relatedBenefits[0].Benefit_Type__c != benefitType) {
                Benefit__c newBenefit = new Benefit__c();
                newBenefit = createBenefitRecord(deathReport, relatedContact, benefitType);
                newBenefitRecords.add(newBenefit);
            }
        }
        insert newBenefitRecords;
        return result;
    }

    public static Benefit__c createBenefitRecord (PBIDataWrapper deathReport, Contact contactMember, String benefitType) {
        Benefit__c newBenefitRecord = new Benefit__c();
        String recordTypeId = '';
        String initiativeStage = '';
        String benefitSubType = '';

        if (benefitType == 'Retirement') { 
            recordTypeId = retrieveRecordTypeId('Benefit__c', 'Retirement');
            benefitSubType = 'Regular Retirement';
            initiativeStage = 'Peer Review';
        } else if (benefitType == 'Death Benefit') {
            recordTypeId = retrieveRecordTypeId('Benefit__c', 'Death Benefit');
            benefitSubType = 'Estate Payments - Post-Ret Death';
            initiativeStage = 'Death Notice';
        }

        newBenefitRecord.PBI_Account__c = deathReport.pbiAccount;
        newBenefitRecord.Member__c = contactMember.Id;
        newBenefitRecord.Group__c = deathReport.pbiGroup;
        newBenefitRecord.City__c = deathReport.city;
        newBenefitRecord.State__c = deathReport.state;
        newBenefitRecord.CU1__c = deathReport.cu1;
        newBenefitRecord.CU2__c = deathReport.cu2;
        newBenefitRecord.CU3__c = deathReport.cu3;
        newBenefitRecord.CU4__c = deathReport.cu4;
        newBenefitRecord.PBI_SSN__c = deathReport.pbiSSN;
        newBenefitRecord.PBI_Last__c = deathReport.pbiLast;
        newBenefitRecord.PBI_First__c = deathReport.pbiFirst;
        newBenefitRecord.PBI_DOB__c = Date.parse(deathReport.pbiDOB);
        newBenefitRecord.Date_of_Death__c = Date.parse(deathReport.pbiDOD);
        newBenefitRecord.PBI_City__c = deathReport.pbiCity;
        newBenefitRecord.PBI_State__c = deathReport.pbiState;
        newBenefitRecord.PBI_Zip__c = deathReport.pbiZip;
        newBenefitRecord.Source__c = deathReport.source;
        newBenefitRecord.Url1__c = deathReport.url1;
        newBenefitRecord.Url2__c = deathReport.url2;
        newBenefitRecord.Url3__c = deathReport.url3;
        newBenefitRecord.Url4__c = deathReport.url4;
        newBenefitRecord.Url5__c = deathReport.url5;
        newBenefitRecord.RecordTypeId = recordTypeId;
        newBenefitRecord.Benefit_Type__c = benefitType;
        newBenefitRecord.Benefit_Sub_Type__c = benefitSubType;
        newBenefitRecord.Initiative_Stage__c = initiativeStage;
        return newBenefitRecord;
    }

    public static String retrieveRecordTypeId(String sObjectApiName, String recordtypeName) {
        String recordTypeId = Schema.getGlobalDescribe().get(sObjectApiName).getDescribe().getRecordTypeInfosByName().get(recordtypeName).getRecordTypeId();
        return recordTypeId;
    }

    public class PBIDataWrapper {
        @AuraEnabled Public String pbiAccount { get; set; }
        @AuraEnabled Public String benefitType { get; set; }
        @AuraEnabled Public String clientSSN { get; set; } 
        @AuraEnabled Public String clientPID { get; set; } 
        @AuraEnabled Public String clientLast { get; set; }
        @AuraEnabled Public String clientFirst { get; set; }
        @AuraEnabled Public String clientDOB { get; set; }
        @AuraEnabled Public String pbiGroup { get; set; }
        @AuraEnabled Public String city { get; set; }
        @AuraEnabled Public String state { get; set; }
        @AuraEnabled Public String cu1 { get; set; }
        @AuraEnabled Public String cu2 { get; set; }
        @AuraEnabled Public String cu3 { get; set; }
        @AuraEnabled Public String cu4 { get; set; }
        @AuraEnabled Public String pbiSSN { get; set; }
        @AuraEnabled Public String pbiLast { get; set; }
        @AuraEnabled Public String pbiFirst { get; set; }
        @AuraEnabled Public String pbiDOB { get; set; }
        @AuraEnabled Public String pbiDOD { get; set; }
        @AuraEnabled Public String pbiCity { get; set; }
        @AuraEnabled Public String pbiState { get; set; }
        @AuraEnabled Public String pbiZip { get; set; }
        @AuraEnabled Public String source { get; set; }
        @AuraEnabled Public String url1 { get; set; }
        @AuraEnabled Public String url2 { get; set; }
        @AuraEnabled Public String url3 { get; set; }
        @AuraEnabled Public String url4 { get; set; }
        @AuraEnabled Public String url5 { get; set; }
    }
}
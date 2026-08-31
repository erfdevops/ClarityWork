trigger LMSSurveyQuestionTrigger on LMS_Survey_Question__c (before insert, before update) {
    
    for (LMS_Survey_Question__c question : Trigger.new) {
        // Check if Question Type is Single Select Response
        if (question.Question_Type__c == 'Single Select Response' && 
            String.isNotBlank(question.Correct_Response__c)) {
            
            // Split the multi-select picklist values by semicolon
            List<String> selectedValues = question.Correct_Response__c.split(';');
            
            // Remove any empty strings from the list
            List<String> cleanValues = new List<String>();
            for (String value : selectedValues) {
                if (String.isNotBlank(value.trim())) {
                    cleanValues.add(value.trim());
                }
            }
            
            // If more than one value is selected, add an error
            if (cleanValues.size() > 1) {
                question.Correct_Response__c.addError('Single Select Response questions can only have one correct answer selected.');
            }
        }
    }
}
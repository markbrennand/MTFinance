/**
 * @description
 * Trigger on Loan object.
 *
 * @author Mark Brennand
 */
trigger Loan on Loan__c (after insert, after update) {
    final Map<Id, Loan__c> oldLoans = Trigger.isUpdate
            ? (Map<Id, Loan__c>) Trigger.oldMap
            : new Map<Id, Loan__c>();

    if (Trigger.isInsert) {
        LoanTriggerHandler.processRecords(TriggerType.CREATED, (List<Loan__c>) Trigger.new, oldLoans);
    } else if (Trigger.isUpdate) {
        LoanTriggerHandler.processRecords(TriggerType.UPDATED, (List<Loan__c>) Trigger.new, oldLoans);
    } else if (Trigger.isDelete) {
        LoanTriggerHandler.processRecords(TriggerType.DELETED, (List<Loan__c>) Trigger.old, oldLoans);
    }
}
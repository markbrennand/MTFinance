/**
 * @description
 * Trigger on Loan_Charge object.
 *
 * @author Mark Brennand
 */
trigger LoanCharge on Loan_Charge__c (after insert, after update, before delete) {
    final Map<Id, Loan_Charge__c> oldLoanCharges = Trigger.isUpdate
            ? (Map<Id, Loan_Charge__c>) Trigger.oldMap
            : new Map<Id, Loan_Charge__c>();

    if (Trigger.isInsert) {
        LoanChargeTriggerHandler.processRecords(TriggerType.CREATED, (List<Loan_Charge__c>) Trigger.new, oldLoanCharges);
    } else if (Trigger.isUpdate) {
        LoanChargeTriggerHandler.processRecords(TriggerType.UPDATED, (List<Loan_Charge__c>) Trigger.new, oldLoanCharges);
    } else if (Trigger.isDelete) {
        LoanChargeTriggerHandler.processRecords(TriggerType.DELETED, (List<Loan_Charge__c>) Trigger.old, oldLoanCharges);
    }
}
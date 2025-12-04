public class PermissionSetBatchProcessor implements Database.Batchable<SObject>, Database.Stateful {
    private String userExternalId;
    private String collectionGroupName;
    private Id userId;
    private Id collectionGroupId;
    private Set<Id> processedPermissionSets = new Set<Id>();
    private Integer assignmentsRemoved = 0;
    
    public PermissionSetBatchProcessor(String userExternalId, String collectionGroupName) {
        this.userExternalId = userExternalId;
        this.collectionGroupName = collectionGroupName;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Step 1: Get the user and collection group
        try {
            User targetUser = [SELECT Id FROM User WHERE External_Id__c = :userExternalId LIMIT 1];
            userId = targetUser.Id;
        } catch (Exception e) {
            System.debug('Error: User not found with External Id: ' + userExternalId);
            return Database.getQueryLocator('SELECT Id FROM User WHERE Id = null');
        }
        
        // Step 2: Get or create Collection Group
        try {
            PermissionSetGroup collGroup = [SELECT Id FROM PermissionSetGroup WHERE DeveloperName = :collectionGroupName LIMIT 1];
            collectionGroupId = collGroup.Id;
        } catch (Exception e) {
            PermissionSetGroup newGroup = new PermissionSetGroup(
                DeveloperName = collectionGroupName,
                MasterLabel = 'Collection Group'
            );
            insert newGroup;
            collectionGroupId = newGroup.Id;
            System.debug('Created new Permission Set Group: ' + collectionGroupName);
        }
        
        // Step 3: Assign group to user if not already assigned
        Boolean needsAssignment = true;
        try {
            List<PermissionSetAssignment> existingAssignments = [
                SELECT Id 
                FROM PermissionSetAssignment 
                WHERE AssigneeId = :userId AND PermissionSetGroupId = :collectionGroupId 
                LIMIT 1
            ];
            
            if (!existingAssignments.isEmpty()) {
                needsAssignment = false;
            }
        } catch (Exception e) {
            // Continue with assignment
        }
        
        if (needsAssignment) {
            insert new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetGroupId = collectionGroupId
            );
        }
        
        // Query ALL permission set assignments for the user (not just direct ones)
        return Database.getQueryLocator([
            SELECT Id, PermissionSetId, PermissionSet.Name, PermissionSetGroupId, PermissionSet.IsOwnedByProfile
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId 
            AND PermissionSet.Name != 'X00ex00000018ozT_128_09_43_34_1'
        ]);
    }
    
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<PermissionSetAssignment> allAssignments = (List<PermissionSetAssignment>)scope;
        
        // Get all permission sets already in Collection Group
        Set<Id> permissionSetsInCollectionGroup = new Set<Id>();
        for (PermissionSetGroupComponent psgc : [
            SELECT PermissionSetId
            FROM PermissionSetGroupComponent
            WHERE PermissionSetGroupId = :collectionGroupId
        ]) {
            permissionSetsInCollectionGroup.add(psgc.PermissionSetId);
            processedPermissionSets.add(psgc.PermissionSetId);
        }
        
        // Separate direct assignments for processing
        List<PermissionSetAssignment> directAssignments = new List<PermissionSetAssignment>();
        for (PermissionSetAssignment psa : allAssignments) {
            if (psa.PermissionSetGroupId == null && !psa.PermissionSet.IsOwnedByProfile) {
                directAssignments.add(psa);
                
                // Ensure we only process each permission set once
                if (!processedPermissionSets.contains(psa.PermissionSetId)) {
                    processedPermissionSets.add(psa.PermissionSetId);
                }
            }
        }
        
        // Filter permission sets that should be added to Collection Group
        List<PermissionSetGroupComponent> newComponents = new List<PermissionSetGroupComponent>();
        List<PermissionSetAssignment> assignmentsToDelete = new List<PermissionSetAssignment>();
        
        for (PermissionSetAssignment psa : directAssignments) {
            // Only add to Collection Group if not already there
            if (!permissionSetsInCollectionGroup.contains(psa.PermissionSetId)) {
                newComponents.add(new PermissionSetGroupComponent(
                    PermissionSetGroupId = collectionGroupId,
                    PermissionSetId = psa.PermissionSetId
                ));
            }
            
            // Always add direct assignments to the delete list
            assignmentsToDelete.add(psa);
        }
        
        // Critical: separate transaction for insert and delete
        Savepoint sp = Database.setSavepoint();
        try {
            // First add to collection group
            if (!newComponents.isEmpty()) {
                insert newComponents;
                System.debug('Added ' + newComponents.size() + ' permission sets to Collection Group.');
            }
            
            // Then remove direct assignments
            if (!assignmentsToDelete.isEmpty()) {
                delete assignmentsToDelete;
                assignmentsRemoved += assignmentsToDelete.size();
                System.debug('Removed ' + assignmentsToDelete.size() + ' direct assignments.');
            }
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error during DML operations: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        System.debug('Process completed. Total assignments removed: ' + assignmentsRemoved);
        System.debug('Total permission sets processed: ' + processedPermissionSets.size());
        
        // Send email notification
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {'admin@example.com'}); // Replace with your email
        mail.setSubject('Permission Set Group Processing Complete');
        mail.setPlainTextBody('Process completed for user ' + userExternalId + 
                             '\nTotal assignments removed: ' + assignmentsRemoved +
                             '\nTotal permission sets processed: ' + processedPermissionSets.size());
        
        try {
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}
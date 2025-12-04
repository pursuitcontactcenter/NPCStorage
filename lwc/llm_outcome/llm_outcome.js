import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { updateRecord } from 'lightning/uiRecordApi';
import LLM_JUSTIFICATION_FIELD from '@salesforce/schema/IndividualApplication.LLM_Justification__c';
import Color_FIELD from '@salesforce/schema/IndividualApplication.color_code__c';
import lwc_set_field from '@salesforce/schema/IndividualApplication.value_set_from_lwc__c';
import manual_outcome from '@salesforce/schema/IndividualApplication.Manual_Review_Outcome__c'
import approval_decision from '@salesforce/schema/IndividualApplication.Status'
export default class LlmOutcome extends LightningElement {
    @api recordId; 
    pdfData;
    showDetails = false;
    showManualDetails=false;
    decision = '';
    justification = '';
    color = '';
    lwcsetdone=false;
    manual_decision='';
    manual_justification='';

    @wire(getRecord, { recordId: '$recordId', fields: [LLM_JUSTIFICATION_FIELD,lwc_set_field,manual_outcome,approval_decision] })
    wiredRecord({ data, error }) {
        if (data) {
            const fieldValue = data.fields.LLM_Justification__c.value;
            this.lwcsetdone = data.fields.value_set_from_lwc__c.value;
            const manualoutcome_fieldValue=data.fields.Manual_Review_Outcome__c.value;
            const approvalstatus_fieldValue=data.fields.Status.value;
            console.log('Field Value:', fieldValue);

            if (fieldValue && !this.showDetails) {
                this.pdfData = fieldValue;
                this.showDetails = true;
                console.log('Raw fieldValue:', JSON.stringify(fieldValue));
                const regex = /Decision:\s*([A-Za-z]+)\s*[\r\n]+Justification:\s*([\s\S]*)/i
                const match = fieldValue.match(regex);
                console.log('Match result:', match);
                if (match) {
                    this.decision = match[1].trim();
                    this.justification = match[2].trim();

                    const decisionLower = this.decision.toLowerCase();

                    if (decisionLower === 'green') {
                        this.color = 'green';
                    } else if (decisionLower === 'amber') {
                        this.color = 'orange';
                    } else {
                        this.color = 'red';
                    }
                }

                console.log('Decision:', this.decision);
                console.log('Justification:', this.justification);
                console.log('Color:', this.color);

                
                if (!this.lwcsetdone) {
                    this.updateField();
                }
                
            }

            if(approvalstatus_fieldValue==='Approved'|| approvalstatus_fieldValue==='Denied')
            {
                this.showManualDetails=true;
                this.manual_decision=approvalstatus_fieldValue==='Approved'?'green':'red';
                this.manual_justification=manualoutcome_fieldValue;
                console.log(this.manual_justification);
            }


        } else if (error) {
            console.error('Error fetching record:', error);
        }
    }

    updateField() {
        const fields = {};
        fields.Id = this.recordId;
        fields[Color_FIELD.fieldApiName] = this.color; 
        fields[lwc_set_field.fieldApiName]=true;
        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                console.log('Record updated successfully');
            })
            .catch(error => {
                console.error('Error updating record:', error);
            });
    }

    

    get divStyle() {
        return `background-color:${this.color}; color:white; padding:6px 14px; border-radius:8px; font-weight:bold; display:inline-block; text-transform:uppercase;`;
    }

    get manualdivStyle() {
        return `background-color:${this.manual_decision}; color:white; padding:6px 14px; border-radius:8px; font-weight:bold; display:inline-block; text-transform:uppercase;`;
    }
}
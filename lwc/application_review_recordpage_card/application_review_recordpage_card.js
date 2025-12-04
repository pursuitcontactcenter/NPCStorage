import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import LLM_JUSTIFICATION_FIELD from '@salesforce/schema/ApplicationReview.SystemOutcome__c';

export default class application_review_recordpage_card extends LightningElement {
    @api recordId; 
    pdfData;
    showDetails = false;
    decision = '';
    justification = '';
    color = '';
    

    @wire(getRecord, { recordId: '$recordId', fields: [LLM_JUSTIFICATION_FIELD] })
    wiredRecord({ data, error }) {
        if (data) {
            const fieldValue = data.fields.SystemOutcome__c.value;
            //this.lwcsetdone = data.fields.value_set_from_lwc__c.value;
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

                
            }


        } else if (error) {
            console.error('Error fetching record:', error);
        }
    }    

    get divStyle() {
        return `background-color:${this.color}; color:white; padding:6px 14px; border-radius:8px; font-weight:bold; display:inline-block; text-transform:uppercase;`;
    }
}
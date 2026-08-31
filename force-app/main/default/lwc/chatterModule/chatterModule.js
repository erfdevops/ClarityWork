import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import USER_CONTACT_ID from '@salesforce/schema/User.ContactId';
import createFeedItemRec from '@salesforce/apex/ChatterModuleController.createFeedItemRec';
import getFeedItemList from '@salesforce/apex/ChatterModuleController.getFeedItemList';

export default class ChatterModule extends NavigationMixin(LightningElement) {
    
    error;
    commentsList;
    wiredApexResult;
    @api contactrecordid;
    @track currentCaseRecord; 
    @track commentBody = '';
    @api userComment;
    @track commentReplies = [];
    @api recFeedItem = {
        Body: '',
        ParentId: '',
        IsRichText: true
    };

    @wire(getRecord, { recordId: USER_ID, fields: [USER_CONTACT_ID] })
    wiredUser({ error, data }) {
        if (data) {
            this.contactrecordid = data.fields.ContactId.value;
        } else if (error) {
            this.error = error;
            console.error('Error fetching user record:', error);
        }
    }

    @wire(getFeedItemList, { parentId: '$contactrecordid' })
    wiredFeedItems(result) {
        this.wiredApexResult = result;
        if (result.data) {
            console.table(result.data);
            this.commentsList = result.data;
            this.insertAdditionalFields();
            this.error = undefined;
        } else if (result.error) {
            this.error = error;
            this.caseRecord = undefined;
        }
    }

    insertAdditionalFields() {
        let iterator = 1;
        this.commentsList = this.commentsList.map(row => ({
            ...row,
            IsMainComment: true,
            IndexDivId: 'commentdiv' + iterator,
            IsIndexEven: iterator++ % 2 === 0 ? true : false,
            FormattedCreatedDate: this.applyDateFormat(row.CreatedDate),
            IsCurrentUser: row.CreatedById === USER_ID // Determine if comment is from current user
        })); 
    }

    handleChange(event) {
        this.commentBody = event.target.value;
    }

    handlePostFeed() {
        this.recFeedItem.Body = this.commentBody;
        this.recFeedItem.ParentId = this.contactrecordid;

        createFeedItemRec({ 'feedItemRec': this.recFeedItem })
            .then(() => {
                // Clear the input field after successful post
                this.commentBody = '';
                
                return refreshApex(this.wiredApexResult);
            })
            .then(() => {
                try {
                    this.insertAdditionalFields();
                    // Use setTimeout to ensure DOM is updated before scrolling
                    setTimeout(() => {
                        this.scrollToTopComment();
                    }, 100);
                } catch (error) {
                    console.error(error);
                }
            })
            .catch((error) => {
                this.error = error;
                console.log(this.error);
            });
    }

    handleSelect(event) {
        const userCommentId = event.detail;
        let userId = this.commentsList.data.find(
            (comment) => comment.Id === userCommentId
        ).CreatedBy.Id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: userId,
                objectApiName: 'User',
                actionName: 'view'
            }
        });
    }

    scrollToTopComment() {
        // Scroll to the last (newest) comment instead of first
        const commentSection = this.template.querySelector('.comment-section');
        if (commentSection) {
            commentSection.scrollTop = commentSection.scrollHeight;
        }
    }

    handleClick(event) {
        event.preventDefault();
        const selectEvent = new CustomEvent('select', {
            detail: this.userComment.Id
        });
        this.dispatchEvent(selectEvent);
    }

    applyDateFormat(recordCreatedDate) {
        let formattedDate = new Date(recordCreatedDate);
        return formattedDate.toDateString() + ' at ' + formattedDate.toLocaleTimeString();   
    }
}
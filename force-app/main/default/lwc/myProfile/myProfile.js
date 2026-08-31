import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';
import getEmployeeData from '@salesforce/apex/MyProfileController.getEmployeeData';
import updateEmployeeData from '@salesforce/apex/MyProfileController.updateEmployeeData';
import isProfileEditAllowed from '@salesforce/apex/MyProfileController.isProfileEditAllowed';

// User fields
const USER_FIELDS = [
    'User.Name',
    'User.Email',
    'User.Phone',
    'User.SmallPhotoUrl'
];

export default class MyProfile extends NavigationMixin(LightningElement) {
    userId = Id;
    @track userName = '';
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track phoneNumber = '';
    @track birthdate = '';
    @track retirementDate = '';
    @track userPhoto = 'https://via.placeholder.com/80';
    
    // Address information (Mailing Address)
    @track mailingStreet = '';
    @track mailingCity = '';
    @track mailingState = '';
    @track mailingPostalCode = '';
    @track mailingCountry = '';
    
    // Profile edit permission
    @track allowProfileEdit = true;

    // Modal states
    @track showEditPersonalModal = false;
    @track showEditAddressModal = false;
    @track isLoading = false;
    @track contactRecord = null;
    
    // Form data for modals
    @track editPersonalData = {
        phoneNumber: '',
        retirementDate: ''
    };
    
    @track editAddressData = {
        mailingStreet: '',
        mailingCity: '',
        mailingState: '',
        mailingPostalCode: '',
        mailingCountry: ''
    };

    @wire(getRecord, { recordId: '$userId', fields: USER_FIELDS })
    wiredUser({ error, data }) {
        if (data) {
            this.userName = data.fields.Name.value;
            this.userPhoto = data.fields.SmallPhotoUrl.value || this.userPhoto;
        } else if (error) {
            console.error('Error loading user data:', error);
        }
    }

    @wire(isProfileEditAllowed)
    wiredProfileEdit({ error, data }) {
        if (data !== undefined) {
            this.allowProfileEdit = data;
        } else if (error) {
            console.error('Error checking profile edit permission:', error);
            this.allowProfileEdit = true;
        }
    }

    @wire(getEmployeeData, { userId: '$userId' })
    wiredContactData({ error, data }) {
        if (data) {
            this.contactRecord = data;
            this.firstName = data.FirstName || '';
            this.lastName = data.LastName || '';
            this.email = data.Email || '';
            this.phoneNumber = data.Phone || '';
            this.birthdate = data.Birthdate || '';
            this.retirementDate = data.Retirement_Date__c || '';
            this.mailingStreet = data.MailingStreet || '';
            this.mailingCity = data.MailingCity || '';
            this.mailingState = data.MailingState || '';
            this.mailingPostalCode = data.MailingPostalCode || '';
            this.mailingCountry = data.MailingCountry || '';
            
            // Initialize edit form data
            this.editPersonalData = {
                phoneNumber: this.phoneNumber,
                retirementDate: this.retirementDate
            };
            
            this.editAddressData = {
                mailingStreet: this.mailingStreet,
                mailingCity: this.mailingCity,
                mailingState: this.mailingState,
                mailingPostalCode: this.mailingPostalCode,
                mailingCountry: this.mailingCountry
            };
        } else if (error) {
            console.error('Error loading contact data:', error);
            this.showToast('Error', 'Failed to load contact information', 'error');
        }
    }

    handleBack() {
        // Dispatch event to navigate back to home
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'home' }
        }));
    }

    handleEditPersonal() {
        this.editPersonalData = {
            phoneNumber: this.phoneNumber,
            retirementDate: this.retirementDate
        };
        this.showEditPersonalModal = true;
    }

    handleEditAddress() {
        this.editAddressData = {
            mailingStreet: this.mailingStreet,
            mailingCity: this.mailingCity,
            mailingState: this.mailingState,
            mailingPostalCode: this.mailingPostalCode,
            mailingCountry: this.mailingCountry
        };
        this.showEditAddressModal = true;
    }

    handlePersonalInputChange(event) {
        const fieldName = event.target.dataset.field;
        this.editPersonalData[fieldName] = event.target.value;
    }

    handleAddressInputChange(event) {
        const fieldName = event.target.dataset.field;
        this.editAddressData[fieldName] = event.target.value;
    }

    handleSavePersonal() {
        this.isLoading = true;
        const dataToUpdate = {
            recordId: this.contactRecord.Id,
            updateData: {
                phoneNumber: this.editPersonalData.phoneNumber,
                retirementDate: this.editPersonalData.retirementDate
            }
        };

        updateEmployeeData(dataToUpdate)
            .then(() => {
                this.phoneNumber = this.editPersonalData.phoneNumber;
                this.retirementDate = this.editPersonalData.retirementDate;
                this.showEditPersonalModal = false;
                this.showToast('Success', 'Personal information updated successfully', 'success');
            })
            .catch(error => {
                console.error('Error updating personal info:', error);
                this.showToast('Error', 'Failed to update personal information', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSaveAddress() {
        this.isLoading = true;
        const dataToUpdate = {
            recordId: this.contactRecord.Id,
            updateData: {
                addressLine1: this.editAddressData.mailingStreet,
                city: this.editAddressData.mailingCity,
                state: this.editAddressData.mailingState,
                postalCode: this.editAddressData.mailingPostalCode,
                country: this.editAddressData.mailingCountry
            }
        };

        updateEmployeeData(dataToUpdate)
            .then(() => {
                this.mailingStreet = this.editAddressData.mailingStreet;
                this.mailingCity = this.editAddressData.mailingCity;
                this.mailingState = this.editAddressData.mailingState;
                this.mailingPostalCode = this.editAddressData.mailingPostalCode;
                this.mailingCountry = this.editAddressData.mailingCountry;
                this.showEditAddressModal = false;
                this.showToast('Success', 'Address information updated successfully', 'success');
            })
            .catch(error => {
                console.error('Error updating address:', error);
                this.showToast('Error', 'Failed to update address information', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleClosePersonalModal() {
        this.showEditPersonalModal = false;
    }

    handleCloseAddressModal() {
        this.showEditAddressModal = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleUpdatePassword() {
        const pageReference = {
            type: 'standard__webPage',
            attributes: {
                url: '/ForgotPassword'
            }
        };
        this[NavigationMixin.Navigate](pageReference);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}
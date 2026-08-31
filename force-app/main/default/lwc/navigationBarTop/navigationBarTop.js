import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import FORM_FACTOR from '@salesforce/client/formFactor';
import NAME_FIELD from '@salesforce/schema/User.Name';
import PHOTO_URL from '@salesforce/schema/User.SmallPhotoUrl';
import ERF_LOGO_SITE from '@salesforce/resourceUrl/ErfTopBarLogo';
import getConsultantData from '@salesforce/apex/NavigationBarTopController.getConsultantData';
import isUserMember from '@salesforce/apex/NavigationBarTopController.isUserMember';

export default class NavigationBarTop extends NavigationMixin(LightningElement) {
    @api navigationItem;
    @track userName;
    @track userPhotoUrl;
    @track error;
    @track desktopScreenStatus = true;
    @track dropdownMenuCssStyle = 'dropdown-content';
    @track consultantName;
    @track consultantPhotoUrl;
    @track consultantPhone;
    @track isMember = false;
    @track showNavBar = false;
    
    connectedCallback() {
        console.log('NavigationBarTop component connected');
        console.log('Requesting consultant data from Apex...');
    }
    
    @wire(isUserMember)
    wiredIsMember({ error, data }) {
        console.log('wiredIsMember callback triggered');
        if (data !== undefined) {
            this.isMember = data;
            this.showNavBar = data;
            console.log('User is member:', this.isMember);
        } else if (error) {
            console.error('Error checking membership status:', error);
            this.showNavBar = false;
        }
    }
    
    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, PHOTO_URL] })
    wiredUser({ error, data }) {
        if (data) {
            const photoUrl = data.fields.SmallPhotoUrl.value;
            console.log('SmallPhotoUrl value:', photoUrl);
            
            // Only set userPhotoUrl if it has a value
            if (photoUrl) {
                this.userPhotoUrl = photoUrl;
                console.log('Profile photo set to:', this.userPhotoUrl);
            } else {
                this.userPhotoUrl = null;
                console.log('SmallPhotoUrl is null or empty, using placeholder');
            }
            
            let userFullName = data.fields.Name.value;
            let userNameArray = userFullName.split(" ");
            this.userName = userNameArray[0];
        } else if (error) {
            this.error = error;
            console.error('Error fetching user record:', error);
        }
    }

    @wire(getConsultantData)
    wiredConsultant({ error, data }) {
        console.log('wiredConsultant callback triggered');
        console.log('Received data:', data);
        console.log('Received error:', error);
        
        if (data) {
            this.consultantName = data.name;
            this.consultantPhotoUrl = data.photoUrl;
            this.consultantPhone = data.phone;
            console.log('=== Consultant Data Loaded ===');
            console.log('Consultant Name:', this.consultantName);
            console.log('Consultant Phone:', this.consultantPhone);
            console.log('Consultant Photo URL:', this.consultantPhotoUrl);
            console.log('Has Data:', data.hasData);
            console.log('Full Consultant Object:', data);
            console.log('================================');
        } else if (error) {
            console.error('Error loading consultant data:', error);
            console.error('Error Details:', error.body?.message || error.message);
            // Don't set error as consultant is optional
        }
    }
    
    toggleProfileMenu() {
        if (this.dropdownMenuCssStyle == 'dropdown-content') {
            this.dropdownMenuCssStyle = 'dropdown-content show-dropdown';
        } else {
            this.dropdownMenuCssStyle = 'dropdown-content'
        }
    }

    closeProfileMenu() {
        this.dropdownMenuCssStyle = 'dropdown-content';
    }

    renderedCallback() {
        // No longer need to inject HTML since we're using a direct image URL
    }

    showMyProfilePage() {
        //console.log('>>>>>>>>>>>>>>>>>>> Child dispatch event!');
        const newNavigationValue = 'myprofile';
        const customEvent = new CustomEvent('showprofilepage', {
            detail: newNavigationValue
        });
        this.dispatchEvent(customEvent);
    }

    callStandardLogout() {
        const pageReference = {
            type: 'comm__loginPage',
            attributes: {
                actionName: "logout"
            }
        };
        this[NavigationMixin.Navigate](pageReference);
    }

    get isDesktopScreen() {
        if (FORM_FACTOR == 'Small' || FORM_FACTOR == 'Medium') {
            this.desktopScreenStatus = false;
        }
        return this.desktopScreenStatus;
    }

    get imageLogoSite() {
        return ERF_LOGO_SITE;
    }
}
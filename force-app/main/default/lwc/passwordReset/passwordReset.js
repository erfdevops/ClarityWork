import { LightningElement, track, api } from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';
import BACKGROUND_IMAGE_ASSET from '@salesforce/contentAssetUrl/unknown_content_asset';
import ERF_LOGO_SITE from '@salesforce/contentAssetUrl/unknown_content_asset';
import ERF_LOGO_LOGIN from '@salesforce/contentAssetUrl/unknown_content_asset';
import handlePasswordReset from '@salesforce/apex/FlexiLoginController.handlePasswordReset';

export default class PasswordReset extends LightningElement {
    
    @track forestUrl = BACKGROUND_IMAGE_ASSET;
    @track desktopScreenStatus = true;
    @track showSuccessMessage = false;
    @track showError = false;
    @track errorMessage = '';
    userName = '';

    connectedCallback(){
        this.backgroundStyle = `background-image: url(${this.forestUrl});`;
    }

    handleUsernameChange(event) {
        this.userName = event.target.value;
        this.showError = false;
        this.showSuccessMessage = false;
    }

    handleReset() {
        if (!this.userName) {
            this.showError = true;
            this.errorMessage = 'Please enter a username';
            return;
        }

        handlePasswordReset({ username: this.userName })
        .then((result) => {
            if (result === 'success') {
                this.showSuccessMessage = true;
                this.showError = false;
                this.userName = '';
            } else {
                this.showError = true;
                this.errorMessage = 'Unable to reset password. Please check your username.';
            }
        })
        .catch((error) => {
            this.showError = true;
            this.errorMessage = error.body?.message || 'An error occurred. Please try again.';
            console.error('*** ERROR: ' + error.body?.message);
        });
    }

    handleCancel() {
        // Navigate back to login page
        window.location.href = '/login';
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

    get imageLogoLogin() {
        return ERF_LOGO_LOGIN;
    }
}
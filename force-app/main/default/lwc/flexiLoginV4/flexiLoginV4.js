import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import FORM_FACTOR from '@salesforce/client/formFactor';
import BACKGROUND_IMAGE_ASSET from '@salesforce/contentAssetUrl/unknown_content_asset';
import handleSiteLogin from '@salesforce/apex/FlexiLoginController.handleSiteLogin';
import ERF_LOGO_LOGIN from '@salesforce/contentAssetUrl/unknown_content_asset';

export default class FlexiLoginV4 extends NavigationMixin(LightningElement) {
    
    @track forestUrl = BACKGROUND_IMAGE_ASSET;
    @track desktopScreenStatus = true;
    @api error = '';
    userName = '';
    userPassword = '';

    connectedCallback(){
        this.backgroundStyle = `background-image: url(${this.forestUrl});`;
    }

    handleUsernameChange(event) {
        this.userName = event.target.value;
    }

    handlePasswordChange(event) {
        this.userPassword = event.target.value;
    }

    handleLogin() {
        handleSiteLogin({ username: this.userName, password: this.userPassword  })
        .then((result) => {
            window.location.href = result;
        })
        .catch((error) => {
            this.error = error;      
            console.log('*** ERROR: ' + error.body.message);
        });
    }

    navigateToResetPassword() {
        const pageReference = {
            type: 'comm__namedPage',
            attributes: {
                name: "Forgot_Password"
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

    get imageLogoLogin() {
        return ERF_LOGO_LOGIN;
    }
}
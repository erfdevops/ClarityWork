import { LightningElement, track, api } from 'lwc';
import homeIcon from '@salesforce/resourceUrl/homeIcon';
import modulesIcon from '@salesforce/resourceUrl/modulesIcon';
import nsHomeIcon from '@salesforce/resourceUrl/nsHomeIcon';
import nsModulesIcon from '@salesforce/resourceUrl/nsModulesIcon';
import nsFileIcon from '@salesforce/resourceUrl/nsFileIcon';
import fileIcon from '@salesforce/resourceUrl/fileIcon';
import chatIcon from '@salesforce/resourceUrl/chatIcon';
import chatIconNew from '@salesforce/resourceUrl/chatIconNew';
import hasUnreadNotifications from '@salesforce/apex/SidebarNotificationController.hasUnreadNotifications';
import markChatterAsViewed from '@salesforce/apex/SidebarNotificationController.markChatterAsViewed';

export default class SidebarNav extends LightningElement {
    @track navItems = [
        { 
            id: 'home', 
            label: 'Home', 
            selectedImageUrl: homeIcon, 
            imageUrl: nsHomeIcon, 
            selected: true 
        },
        { 
            id: 'program', 
            label: 'Modules', 
            selectedImageUrl: modulesIcon, 
            imageUrl: nsModulesIcon, 
            selected: false 
        },
        { 
            id: 'myfiles', 
            label: 'My Files', 
            selectedImageUrl: nsFileIcon, 
            imageUrl: fileIcon, 
            selected: false 
        },
        { 
            id: 'myresources', 
            label: 'My Resources', 
            selectedImageUrl: nsFileIcon, 
            imageUrl: fileIcon, 
            selected: false 
        },
        { 
            id: 'mychatter', 
            label: 'Engage', 
            selectedImageUrl: chatIcon, 
            imageUrl: chatIcon, 
            selected: false 
        }/*,
        { 
            id: 'myprofile', 
            label: 'My Profile', 
            selectedImageUrl: homeIcon, 
            imageUrl: nsHomeIcon, 
            selected: false 
        }*/
    ];

    @track hasNotifications = false;

    connectedCallback() {
        this.checkNotifications();
    }

    async checkNotifications() {
        try {
            this.hasNotifications = await hasUnreadNotifications();
            this.updateChatIcon();
        } catch (error) {
            console.error('Error checking notifications:', error);
        }
    }

    updateChatIcon() {
        const chatIconToUse = this.hasNotifications ? chatIconNew : chatIcon;
        this.navItems = this.navItems.map(item => {
            if (item.id === 'mychatter') {
                return {
                    ...item,
                    selectedImageUrl: chatIconToUse,
                    imageUrl: chatIconToUse
                };
            }
            return item;
        });
    }

    async handleSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.navItems = this.navItems.map(item => ({
            ...item,
            selected: item.id === selectedId
        }));
        this.dispatchEvent(new CustomEvent('navchange', { detail: selectedId }));
        
        // If user clicked on the Engage section, mark it as viewed
        if (selectedId === 'mychatter') {
            try {
                await markChatterAsViewed();
                // Immediately check notifications to update the icon
                await this.checkNotifications();
            } catch (error) {
                console.error('Error marking chatter as viewed:', error);
            }
        } else {
            // Check for notifications when navigating to refresh the icon
            await this.checkNotifications();
        }
    }

    // API method to programmatically set the selected navigation item
    @api
    setSelectedNav(navId) {
        this.navItems = this.navItems.map(item => ({
            ...item,
            selected: item.id === navId
        }));
    }
}
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

// Apex methods
import initializeSharePointConfig from '@salesforce/apex/SharePointSyncController.initializeSharePointConfig';
import getFolderList from '@salesforce/apex/SharePointSyncController.getFolderList';
import getSyncedFiles from '@salesforce/apex/SharePointSyncController.getSyncedFiles';
import syncFilesToSharePoint from '@salesforce/apex/SharePointSyncController.syncFilesToSharePoint';

const COLUMNS = [
    { label: 'File Name', fieldName: 'File_Name__c', type: 'text' },
    { label: 'Folder Name', fieldName: 'Folder_Name__c', type: 'text' },
    { 
        label: 'SharePoint URL', 
        fieldName: 'SharePoint_URL__c', 
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'File_Name__c' },
            target: '_blank'
        }
    }
];

export default class SharepointFileSync extends LightningElement {
    @api recordId; // Current record ID from the record page
    @api objectApiName; // Object API name from the record page
    
    @track folders = [];
    @track selectedFolder = '';
    @track syncedFiles = [];
    @track isLoading = false;
    @track isInitialized = false;
    @track configData = null;
    @track isObjectSpecific = false; // New: flag to determine if config is object-specific
    @track displayFolderName = ''; // New: folder name to display when object-specific
    
    columns = COLUMNS;
    wiredSyncedFilesResult;

    // Component lifecycle
    connectedCallback() {
        this.initializeComponent();
    }

    // Initialize SharePoint configuration on component load
    async initializeComponent() {
        this.isLoading = true;
        const startTime = Date.now();
        const MINIMUM_LOADING_TIME = 5000; // 5 seconds minimum loading time
        
        try {
            console.log('Initializing SharePoint configuration...');
            
            // Step 1: Initialize SharePoint (get token, site ID, drive ID)
            // Retry logic in case metadata hasn't been deployed yet
            let config;
            let retryCount = 0;
            const MAX_RETRIES = 3;
            
            while (retryCount < MAX_RETRIES) {
                try {
                    config = await initializeSharePointConfig();
                    this.configData = config;
                    console.log('SharePoint configuration initialized:', config);
                    
                    // Check if this configuration is object-specific
                    if (config.objectApiName && config.objectApiName === this.objectApiName && config.folderName) {
                        this.isObjectSpecific = true;
                        this.selectedFolder = config.folderName;
                        this.displayFolderName = config.folderName;
                        console.log('Object-specific configuration detected. Folder:', config.folderName);
                    }
                    
                    break; // Success, exit retry loop
                } catch (error) {
                    retryCount++;
                    if (retryCount < MAX_RETRIES) {
                        console.log(`Retry ${retryCount}/${MAX_RETRIES} - waiting 2 seconds...`);
                        await this.sleep(2000); // Wait 2 seconds before retry
                    } else {
                        throw error; // Max retries reached, throw error
                    }
                }
            }
            
            // IMPORTANT: Wait 3 seconds after token generation to ensure metadata is committed
            // This prevents "uncommitted work pending" errors when calling getFolderList
            console.log('Waiting 3 seconds for metadata deployment to complete...');
            await this.sleep(3000);
            
            // Step 2: Get folder list for dropdown (with retry logic)
            // Skip this if object-specific configuration is detected
            if (!this.isObjectSpecific) {
                let folderList;
                let folderRetryCount = 0;
                const MAX_FOLDER_RETRIES = 2;
                
                while (folderRetryCount < MAX_FOLDER_RETRIES) {
                    try {
                        folderList = await getFolderList();
                        console.log('Folders loaded successfully');
                        break; // Success, exit retry loop
                    } catch (error) {
                        folderRetryCount++;
                        if (folderRetryCount < MAX_FOLDER_RETRIES) {
                            console.log(`Folder retrieval retry ${folderRetryCount}/${MAX_FOLDER_RETRIES} - waiting 2 seconds...`);
                            await this.sleep(2000); // Wait before retry
                        } else {
                            throw error; // Max retries reached, throw error
                        }
                    }
                }
                
                this.folders = folderList.map(folder => ({
                    label: folder,
                    value: folder
                }));
                console.log('Folders loaded:', this.folders);
            } else {
                console.log('Skipping folder list retrieval - using object-specific folder:', this.displayFolderName);
            }
            
            // Ensure minimum loading time has passed (so metadata has time to deploy)
            const elapsedTime = Date.now() - startTime;
            if (elapsedTime < MINIMUM_LOADING_TIME) {
                const remainingTime = MINIMUM_LOADING_TIME - elapsedTime;
                console.log(`Waiting ${remainingTime}ms to ensure metadata is deployed...`);
                await this.sleep(remainingTime);
            }
            
            this.isInitialized = true;
            this.showToast('Success', 'SharePoint connection established', 'success');
            
        } catch (error) {
            console.error('Error initializing SharePoint:', error);
            this.showToast('Error', 'Failed to initialize SharePoint: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Helper method to sleep/wait
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // Wire to get synced files for the current record
    @wire(getSyncedFiles, { recordId: '$recordId', folderName: '$selectedFolder' })
    wiredSyncedFiles(result) {
        this.wiredSyncedFilesResult = result;
        if (result.data) {
            this.syncedFiles = result.data;
            console.log('Synced files loaded:', this.syncedFiles);
        } else if (result.error) {
            console.error('Error loading synced files:', result.error);
        }
    }

    // Handle folder selection change
    handleFolderChange(event) {
        this.selectedFolder = event.detail.value;
        console.log('Selected folder:', this.selectedFolder);
    }

    // Handle Sync button click
    async handleSync() {
        if (!this.selectedFolder) {
            this.showToast('Warning', 'Please select a folder first', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            console.log('Starting sync for record:', this.recordId, 'to folder:', this.selectedFolder);
            
            const result = await syncFilesToSharePoint({
                recordId: this.recordId,
                folderName: this.selectedFolder
            });
            
            console.log('Sync result:', result);
            
            // Refresh the synced files list
            await refreshApex(this.wiredSyncedFilesResult);
            
            this.showToast('Success', result, 'success');
            
        } catch (error) {
            console.error('Error syncing files:', error);
            this.showToast('Error', 'Failed to sync files: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Get error message from error object
    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        }
        return 'Unknown error';
    }

    // Show toast notification
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    // Computed properties
    get hasFiles() {
        return this.syncedFiles && this.syncedFiles.length > 0;
    }

    get hasFolders() {
        return this.folders && this.folders.length > 0;
    }

    get showFolderDropdown() {
        return !this.isObjectSpecific;
    }

    get showFolderName() {
        return this.isObjectSpecific && this.displayFolderName;
    }
}
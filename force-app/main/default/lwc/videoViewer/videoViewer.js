import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVideoFile from '@salesforce/apex/FileUploadController.getVideoFile';

export default class VideoViewer extends LightningElement {
    @api lessonId;
    @api heightInRem = 30; // Default height for video player (480px / 16 = 30rem)
    
    @track isLoading = false;
    @track error;
    @track videoUrl;
    @track fileName;
    @track fileId;
    @track contentDocumentId;
    @track hasVideoFile = false;

    get videoHeight() {
        return this.heightInRem + 'rem';
    }

    get containerStyle() {
        return `width: 100%; height: ${this.videoHeight}; position: relative;`;
    }

    get videoStyle() {
        // Calculate height minus the controls bar (approximately 40px = 2.5rem)
        const videoHeight = this.heightInRem - 2.5;
        return `width: 100%; height: ${videoHeight}rem; border: 1px solid #d9dbdd; border-top: none; border-radius: 0 0 4px 4px;`;
    }

    connectedCallback() {
        if (this.lessonId) {
            this.loadVideoFile();
        }
    }

    @api
    refreshVideo() {
        if (this.lessonId) {
            this.loadVideoFile();
        }
    }

    async loadVideoFile() {
        this.isLoading = true;
        this.error = null;
        this.videoUrl = null;
        this.fileName = null;
        this.fileId = null;
        this.contentDocumentId = null;
        this.hasVideoFile = false;

        try {
            const result = await getVideoFile({ lessonId: this.lessonId });
            
            if (result && result.fileId) {
                this.fileId = result.fileId;
                this.contentDocumentId = result.contentDocumentId;
                this.fileName = result.fileName;
                this.hasVideoFile = true;
                
                // Use ContentVersionId for Community compatibility
                // Works in both Org and Experience Cloud
                this.videoUrl = `/sfc/servlet.shepherd/version/download/${result.fileId}`;
                
            } else {
                this.hasVideoFile = false;
                this.error = 'No video file found for this lesson.';
            }
            
        } catch (error) {
            console.error('Error loading video file:', error);
            this.error = 'Failed to load video file: ' + (error.body?.message || error.message);
            this.hasVideoFile = false;
        } finally {
            this.isLoading = false;
        }
    }

    handleDownload() {
        if (this.contentDocumentId) {
            // Create download URL using ContentDocument ID for consistency
            const downloadUrl = `/sfc/servlet.shepherd/document/download/${this.contentDocumentId}`;
            
            // Create a temporary link and trigger download
            const link = document.createElement('a');
            link.href = downloadUrl;
            link.download = this.fileName || 'lesson-video.mp4';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            
            this.showToast('Success', 'Download started', 'success');
        }
    }

    handleOpenNewWindow() {
        if (this.contentDocumentId) {
            const videoUrl = `/sfc/servlet.shepherd/document/download/${this.contentDocumentId}`;
            window.open(videoUrl, '_blank', 'width=800,height=600,scrollbars=yes,resizable=yes');
        }
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
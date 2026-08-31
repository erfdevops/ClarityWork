import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPdfFile from '@salesforce/apex/FileUploadController.getPdfFile';

export default class PdfViewer extends LightningElement {
    @api lessonId;
    @api heightInRem = 75; // Much larger height for better PDF viewing (1200px / 16 = 75rem)
    
    @track isLoading = false;
    @track error;
    @track pdfUrl;
    @track fileName;
    @track fileId;
    @track contentDocumentId;
    @track hasPdfFile = false;

    get pdfHeight() {
        return this.heightInRem + 'rem';
    }

    get containerStyle() {
        return `width: 100%; height: ${this.pdfHeight}; position: relative;`;
    }

    get iframeStyle() {
        // Calculate height minus the controls bar (approximately 40px = 2.5rem)
        const iframeHeight = this.heightInRem - 2.5;
        return `width: 100%; height: ${iframeHeight}rem; border: 1px solid #d9dbdd; border-top: none; border-radius: 0 0 4px 4px;`;
    }

    connectedCallback() {
        if (this.lessonId) {
            this.loadPdfFile();
        }
    }

    @api
    refreshPdf() {
        if (this.lessonId) {
            this.loadPdfFile();
        }
    }

    async loadPdfFile() {
        this.isLoading = true;
        this.error = null;
        this.pdfUrl = null;
        this.fileName = null;
        this.fileId = null;
        this.contentDocumentId = null;
        this.hasPdfFile = false;

        try {
            const result = await getPdfFile({ lessonId: this.lessonId });
            
            if (result) {
                this.fileName = result.fileName;
                
                // Check if it's an external URL from File_Url__c field
                if (result.isExternalUrl && result.fileUrl) {
                    this.pdfUrl = result.fileUrl;
                    this.hasPdfFile = true;
                    console.log('Using external PDF URL from File_Url__c field:', this.pdfUrl);
                } 
                // Otherwise use the uploaded file
                else if (result.fileId) {
                    this.fileId = result.fileId;
                    this.contentDocumentId = result.contentDocumentId;
                    this.hasPdfFile = true;
                    
                    // Use ContentVersionId for Community compatibility
                    this.pdfUrl = `/sfc/servlet.shepherd/version/download/${result.fileId}`;
                    console.log('Using uploaded PDF file:', this.fileName);
                } else {
                    this.hasPdfFile = false;
                    this.error = 'No PDF file found for this lesson.';
                }
            } else {
                this.hasPdfFile = false;
                this.error = 'No PDF file found for this lesson.';
            }
            
        } catch (error) {
            console.error('Error loading PDF file:', error);
            this.error = 'Failed to load PDF file: ' + (error.body?.message || error.message);
            this.hasPdfFile = false;
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
            link.download = this.fileName || 'lesson-document.pdf';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            
            this.showToast('Success', 'Download started', 'success');
        }
    }

    handleOpenNewWindow() {
        if (this.contentDocumentId) {
            const pdfUrl = `/sfc/servlet.shepherd/document/download/${this.contentDocumentId}`;
            window.open(pdfUrl, '_blank', 'width=800,height=900,scrollbars=yes,resizable=yes');
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}
import { LightningElement, track, api, wire } from 'lwc';
import uploadFile from '@salesforce/apex/FileUploadController.uploadFile';
import getUploadedFiles from '@salesforce/apex/FileUploadController.getUploadedFiles';
import deleteFile from '@salesforce/apex/FileUploadController.deleteFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class FileUploader extends LightningElement {
    @api lessonWeekAssignmentId; // Lesson Week Assignment ID to associate files with
    @api assignmentDueDate; // Due date passed from parent
    @api assignmentExtensionDate; // Extension date passed from parent
    @track uploadedFiles = [];
    @track isSubmitting = false;
    @track existingFiles = [];
    @track isUploading = false;
    wiredFilesResult;

    // Wire method to get existing uploaded files for this lesson week assignment
    @wire(getUploadedFiles, { lessonWeekAssignmentId: '$lessonWeekAssignmentId' })
    wiredFiles(result) {
        this.wiredFilesResult = result;
        
        if (result.data) {
            this.existingFiles = result.data;
        } else if (result.error) {
            console.error('Error loading existing files:', result.error);
            this.existingFiles = [];
            this.showToast('Error', 'Failed to load existing files', 'error');
        } else {
            // No data and no error - likely null lessonWeekAssignmentId
            this.existingFiles = [];
        }
    }

    get hasFiles() {
        return this.uploadedFiles.length > 0;
    }

    get hasExistingFiles() {
        return this.existingFiles && this.existingFiles.length > 0;
    }

    get allowUploads() {
        return this.lessonWeekAssignmentId != null;
    }

    get fileCountText() {
        const count = this.uploadedFiles.length;
        return count === 1 ? '1 file' : `${count} files`;
    }

    get totalSizeText() {
        const totalBytes = this.uploadedFiles.reduce((sum, file) => sum + file.size, 0);
        return this.formatFileSize(totalBytes);
    }

    handleBrowseClick() {
        const fileInput = this.template.querySelector('.file-input');
        fileInput.click();
    }

    handleFileSelect(event) {
        const files = Array.from(event.target.files);
        this.processFiles(files);
        
        // Clear the input so the same file can be selected again
        event.target.value = '';
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const uploadArea = this.template.querySelector('.upload-area');
        uploadArea.classList.remove('drag-over');
        
        const files = Array.from(event.dataTransfer.files);
        this.processFiles(files);
    }

    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
    }

    handleDragEnter(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const uploadArea = this.template.querySelector('.upload-area');
        uploadArea.classList.add('drag-over');
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const uploadArea = this.template.querySelector('.upload-area');
        uploadArea.classList.remove('drag-over');
    }

    handleRemoveFile(event) {
        const fileId = event.target.dataset.fileId;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.id !== fileId);
    }

    processFiles(files) {
        const maxFileSize = 10 * 1024 * 1024; // 10MB limit
        const allowedTypes = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'text/plain',
            'image/jpeg',
            'image/jpg',
            'image/png',
            'application/zip'
        ];

        files.forEach(file => {
            // Validate file size
            if (file.size > maxFileSize) {
                this.showToast('Error', `File "${file.name}" is too large. Maximum size is 10MB.`, 'error');
                return;
            }

            // Validate file type
            if (!allowedTypes.includes(file.type)) {
                this.showToast('Error', `File type "${file.type}" is not allowed.`, 'error');
                return;
            }

            // Check for duplicates
            const isDuplicate = this.uploadedFiles.some(existingFile => 
                existingFile.name === file.name && existingFile.size === file.size
            );

            if (isDuplicate) {
                this.showToast('Warning', `File "${file.name}" is already selected.`, 'warning');
                return;
            }

            // Add file to the list
            const fileData = {
                id: this.generateId(),
                name: file.name,
                size: file.size,
                sizeFormatted: this.formatFileSize(file.size),
                type: file.type,
                file: file,
                uploading: false,
                lastUpdated: this.formatTimestamp(new Date())
            };

            this.uploadedFiles = [...this.uploadedFiles, fileData];
        });
    }

    async handleSubmitAssignment() {
        if (this.uploadedFiles.length === 0) {
            this.showToast('Error', 'Please select at least one file to submit.', 'error');
            return;
        }

        if (!this.lessonWeekAssignmentId) {
            this.showToast('Error', 'No lesson week assignment selected for file upload.', 'error');
            return;
        }

        this.isSubmitting = true;
        this.isUploading = true;

        try {
            // Upload each file to Salesforce
            const uploadPromises = this.uploadedFiles.map(file => this.uploadSingleFile(file));
            await Promise.all(uploadPromises);

            // Clear the uploaded files array since they're now saved
            this.uploadedFiles = [];
            
            // Refresh the existing files list
            await refreshApex(this.wiredFilesResult);

            this.showToast('Success', 'Files uploaded successfully!', 'success');
            
            // Dispatch success event to parent
            this.dispatchEvent(new CustomEvent('assignmentsubmitted', {
                detail: {
                    files: this.uploadedFiles,
                    timestamp: new Date().toISOString()
                },
                bubbles: true
            }));

            this.showToast('Success', 'Assignment submitted successfully!', 'success');
        } catch (error) {
            console.error('File upload error:', error);
            this.showToast('Error', 'Failed to upload files: ' + error.body.message, 'error');
        } finally {
            this.isSubmitting = false;
            this.isUploading = false;
        }
    }

    async uploadSingleFile(fileData) {
        try {
            // Convert file to base64
            const base64 = await this.fileToBase64(fileData.file);
            
            // Call Apex method to upload file
            const result = await uploadFile({
                base64Data: base64,
                fileName: fileData.name,
                lessonWeekAssignmentId: this.lessonWeekAssignmentId
            });
            
            return result;
        } catch (error) {
            console.error('Error uploading file:', fileData.name, error);
            throw error;
        }
    }

    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => {
                // Remove the data URL prefix to get just the base64 data
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = error => reject(error);
        });
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    formatTimestamp(date) {
        const day = date.getDate().toString().padStart(2, '0');
        const month = date.toLocaleString('default', { month: 'short' });
        const year = date.getFullYear();
        const hours = date.getHours().toString().padStart(2, '0');
        const minutes = date.getMinutes().toString().padStart(2, '0');
        
        return `${day} ${month} ${year}, ${hours}:${minutes} PM`;
    }

    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    }

    handleDownloadFile(event) {
        const contentDocumentId = event.target.dataset.fileId;
        if (contentDocumentId) {
            // Direct download using the ContentDocument's file endpoint
            // This will trigger a download instead of opening in viewer
            const downloadUrl = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
            const link = document.createElement('a');
            link.href = downloadUrl;
            link.download = true;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}
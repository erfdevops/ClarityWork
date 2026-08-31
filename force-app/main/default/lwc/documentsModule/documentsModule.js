import { LightningElement, track, api } from 'lwc';
import Toast from 'lightning/toast';
import USER_ID from '@salesforce/user/Id';
import uploadNewFile from '@salesforce/apex/DocumentsModuleController.uploadNewFile';
import deleteSelectedFile from '@salesforce/apex/DocumentsModuleController.deleteSelectedFile';
import getFilesRelatedToUser from '@salesforce/apex/DocumentsModuleController.getFilesRelatedToUser';
import EmptyStateImage from '@salesforce/resourceUrl/EmptyState';

export default class DocumentsModule extends LightningElement {

    @api tableColumns = [
        { label: 'Document Name', fieldName: 'documentTitle', sorting: true, class: '', style: '' },
        { label: 'Related To', fieldName: 'relatedTo', sorting: true, class: '', style: '' },
        { label: 'Date Uploaded', fieldName: 'dateUploaded', sorting: true, class: '', style: '' },
        { label: 'File Format', fieldName: 'fileFormat', sorting: false, class: '', style: '' }
    ];
    @api tableactions = [
        { actionLabel: 'Download' },
        { actionLabel: 'Delete' }
    ];

    @api filesUploadResult;
    @api noFilesAvailable = false;
    @api fieldsList = [];
    @track tableData = [];
    @track paginatedTableData = [];

    sortedBy;
    sortDirection = 'asc';
    emptyStateImageUrl = EmptyStateImage;
    
    @api tabletitle = 'My Files';   
    @api showUploadFileModal = false;
    @api showInputFile = false;
    @api tableHasActions = false;

    @api paginationsize = 10;
    @track pagesArray = [];
    @track pagesAmount = 1;
    @track currentPage = 1;
    @track pageIndex = 1;
    
    @track listStart = 0;
    @track listEnds;
    @track listSize;

    @track actionMenuStyle = 'action-menu-toggle-off';
    @track tableStyleForColumnLabels = 'table-row-label';
    @track tableStyleForCells = 'table-row-data';
    
    @track filesToUpload = [];
    @track fileParentId = '';
    @track base64UploadedFile = '';
    @track uploadedFileName = '';
    @track isFileFaq = false;

    connectedCallback() {
        this.getAllUserFiles();
        this.tableHasActions = true;
    }
    
    getAllUserFiles() {
        getFilesRelatedToUser({ currentUserId: USER_ID })
        .then(result => {
            try {
                let errorResult = false;
                let dataResult = JSON.parse(result);
                for (const key in dataResult) {
                    errorResult = this.checkForErrorsFromController(dataResult[key]);
                }

                if (errorResult) {
                    this.noFilesAvailable = true;
                } else {
                    
                    this.tableData = dataResult;

                    this.paginatedTableData = dataResult

                    this.listSize = this.tableData.length;
                    this.initializePagination();
                }
            } catch (parseError) {
                console.error('Error parsing data: ', parseError);
            }
        })
        .catch(error => {
            console.error('Error fetching data from Apex:', error);
            console.log('Error Apex: ' + JSON.stringify(error));
        });
    }

    uploadNewFilesToApex() {
        //uploadNewFile({ parentId: this.fileParentId, base64Data: this.base64UploadedFile , newFileName: this.uploadedFileName, isFaq: this.isFileFaq })
        uploadNewFile({ parentId: this.fileParentId, base64Data: this.base64UploadedFile , newFileName: this.uploadedFileName })
        .then(result => {
            this.filesUploadResult = result;
            if (this.filesUploadResult) {
                let uploadMessage = 'file was';

                if (this.filesToUpload.length > 1) {
                    uploadMessage = 'files were';
                }

                this.showLwcToast('File Upload', 'The ' + uploadMessage + ' uploaded successfully.', 'success');
                this.getAllUserFiles();
            } else {
                this.showLwcToast('File Upload', 'No files were uploaded.', 'warning');
            }
        })
        .catch(error => {
            this.showLwcToast('File Upload', 'Contact your Admin - Error: ' + error.message, 'error');
            console.log('Error: ' + JSON.stringify(error));
        });
    }

    async saveNewUploadedFiles() {
        try {
            if (this.filesToUpload.length > 0) {
                for (let i = 0; i < this.filesToUpload.length; i++) {
                    this.fileParentId = this.tableData[i].parentId;
                    this.uploadedFileName = this.filesToUpload[i].name;
                    //this.uploadedFileName = this.filesUpload[i].fullName;
                    //this.isFileFaq = this.filesToUpload[i].isFaq;
                    this.base64UploadedFile = await this.newFileToBase64(this.filesToUpload[i]);                    
                    this.uploadNewFilesToApex();
                }

                this.closeFileUploader();
            } else {
                this.showLwcToast('File Upload', 'No files were selected.', 'warning');
            }

        } catch (error) {
            console.error(error);
        } 
    }

    newFileToBase64(newFile) {
        return new Promise((resolve, reject) => {
            const newFileReader = new FileReader();
            newFileReader.onload = () => {
                const readerResult = newFileReader.result.split(',')[1];
                resolve(readerResult);
            };
            newFileReader.onerror = error => reject(error);
            newFileReader.readAsDataURL(newFile);
        });
    }

    handleDeleteDocument(event) {
        let referenceId = event.currentTarget.dataset.rowid;
        let referenceName = event.currentTarget.dataset.rowname;
        let confirmMessage = 'Are you sure you want to delete the file: ' + referenceName + '?';

        let deleteStatus = confirm(confirmMessage);
        if (deleteStatus) {
            try {
                deleteSelectedFile({ contentDocumentId : referenceId })
                .then(result => {
                    if (result) {
                        this.showLwcToast('File Deletion', 'The files were deleted successfully.', 'success');
                        this.getAllUserFiles();
                    } else {
                        this.showLwcToast('File Deletion', 'No files were deleted.', 'warning');
                    }
                })
                .catch(error => {
                    this.showLwcToast('File Deletion', 'Contact your Admin - Error: ' + error.message, 'error');
                    console.error('Error from Apex result:', error);
                });

            } catch (parseError) {
                console.error('Error parsing data: ', parseError);
            }
        }        
    }

    fileUploadDragOverHandler(event) {
        event.preventDefault();
        event.stopPropagation();
    }

    fileUploadDropHandler(event) {
        event.preventDefault();
        event.stopPropagation();
        let newDataTransferFiles =  event.dataTransfer.files;
        this.handleUploadedFiles(newDataTransferFiles);
    }

    fileUploadThroughInput(event) {
        let newTargetFiles = event.target.files;
        this.handleUploadedFiles(newTargetFiles);
    }

    handleUploadedFiles(newFilesToUpload) {
        for (let i = 0; i < newFilesToUpload.length; i++) {
            let fileName = newFilesToUpload[i].name;
            //newFilesToUpload[i].fullName = fileName;
            newFilesToUpload[i].cleanName = fileName.replace(".pdf", "");
            newFilesToUpload[i].indexKey = i;
            //newFilesToUpload[i].isFaq = false;
        }
        this.filesToUpload = newFilesToUpload;
    }

    checkForErrorsFromController(stringValue) {
        let errorStatus = false;
        let errorMessage1 = 'There is no Contact record associated to this User';
        let errorMessage2 = 'There are no Files associated to this User Contact record';
        let errorMessage3 = 'There are no Benefit records associated to this User Contact record';

        if (stringValue == errorMessage1 || stringValue == errorMessage2 || stringValue == errorMessage3) {
            errorStatus = true;
        }

        return errorStatus;
    }

    fileUploadClickHandler() {
        this.showInputFile = true;
    }

    openFileUploader() {
        this.showUploadFileModal = true;
    }

    closeFileUploader() {
        this.showUploadFileModal = false;
        this.showInputFile = false;
        this.filesToUpload = [];
    }

    sortDataByColumn(event) {
        const field = event.currentTarget.dataset.sortingfield;

        if (this.sortedBy === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortDirection = 'asc';
        }

        this.sortedBy = field;
        const direction = this.sortDirection === 'asc' ? 1 : -1;
        let sortedData = [...this.tableData].sort((a, b) => {
            let aVal = a[field] || '';
            let bVal = b[field] || '';

            return aVal.toString().localeCompare(bVal.toString()) * direction;
        });

        this.tableData = sortedData;
        this.initializePagination();
    }

    initializePagination() {
        this.currentPage = 1;
        this.pageIndex = 1;
        this.listStart = 0;
        this.listEnds = this.paginationsize;
        let listTotalSize = this.tableData.length;
        
        this.pagesAmount = Math.ceil(listTotalSize / this.paginationsize);
        let iterations = this.pagesAmount <= 5 ? this.pagesAmount : 5;
        this.pagesArray = [];

        for (let i = 0; i < iterations; i++) {
            let pageNumber =  i + 1; 
            let pageId = 'page-id-' + pageNumber;
            let cssStyle = pageNumber == 1 ? 'page-number-current' : 'page-number';
            this.pagesArray.push({ pageNumber: pageNumber, cssClass: cssStyle, pageId: pageId});
        }

        this.sortDataByPagination();
    }

    sortDataByPagination() {
        let paginatedData = [];
        let dataTable = this.tableData;
        for (let i = this.listStart; i < this.listEnds; i++) {
            if (i < this.tableData.length) {
                paginatedData.push(dataTable[i]);
            }
        }
        this.paginatedTableData = paginatedData;
    }

    handlePageNavigation(selectedPage) {
        this.currentPage = selectedPage;
        this.listStart = (selectedPage - 1) * this.paginationsize;
        this.listEnds = this.listStart + this.paginationsize;
        const startPage = Math.floor((selectedPage - 1) / 5) * 5 + 1;
        const endPage = Math.min(startPage + 4, this.pagesAmount);
        this.pagesArray = [];

        for (let i = startPage; i <= endPage; i++) {
            this.pagesArray.push({
                pageNumber: i,
                pageId: 'page-id-' + i,
                cssClass: i === selectedPage
                    ? 'page-number-current'
                    : 'page-number'
            });
        }

        this.sortDataByPagination();
    }

    handleDirectPageClick(event) {
        const selectedPage = Number(event.currentTarget.dataset.page);
        this.handlePageNavigation(selectedPage);
    }

    paginationPrevious() {
        if (this.currentPage > 1) {
            this.handlePageNavigation(this.currentPage - 1);
        }
    }

    paginationNext() {
        if (this.currentPage < this.pagesAmount) {
            this.handlePageNavigation(this.currentPage + 1);
        }
    }

    toggleActionMenu(event) {
        this.untoggleActionMenu();
        let recordReferenceId = event.currentTarget.dataset.recordid;
        this.template.querySelector('[data-reference-id="' + recordReferenceId + '"]').className = 'action-menu-toggle-on';
    }

    untoggleActionMenu() {
        this.template.querySelectorAll('.action-menu-toggle-on').forEach(element => {
            element.className = 'action-menu-toggle-off';
        });
    }

    handleFileRename(event) {
        let fileIndexKey = event.currentTarget.dataset.indexkey;
        let newFileName = event.currentTarget.value;
        let updatedFiles = [];

        for (let i = 0; i < this.filesToUpload.length; i++) {
            let originalFile = this.filesToUpload[i];
            let fileName = originalFile.name;
            
            if (fileIndexKey == i) {
                fileName = newFileName;
            }
            
            let renamedFile = new File( [originalFile], fileName, { type: originalFile.type });
            renamedFile.cleanName = originalFile.cleanName;
            renamedFile.indexKey = originalFile.indexKey;
            updatedFiles.push(renamedFile);
        }

        this.filesToUpload = updatedFiles;
    }

    showLwcToast(toastLabel, toastMessage, toastVariant) {
        Toast.show({
            label: toastLabel,
            message: toastMessage,
            variant: toastVariant,
            mode: 'dismissable'
        }, this);
    }

    get recordsAmount() {
        let recordsPerPage = 0;
        
        if (this.currentPage < this.pagesAmount) {
            recordsPerPage = this.currentPage * 10;
        } else {
            recordsPerPage = this.listSize;
        }

        return recordsPerPage;
    }
}
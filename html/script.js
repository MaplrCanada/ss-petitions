// Global variables
let petitions = [];
let playerData = {};
let configData = {};
let currentPetition = null;

// Initialize when NUI message is received
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'openMenu') {
        // Store the data
        petitions = data.petitions || [];
        playerData = data.playerData || {};
        configData = data.config || {};
        
        // Initialize the UI
        initializeUI();
        
        // Show the container
        document.getElementById('petition-container').style.display = 'block';
    }
});

// Initialize the UI
function initializeUI() {
    // Show/hide admin tab based on permissions
    const adminTab = document.getElementById('admin-tab');
    if (playerData.isAdmin) {
        adminTab.style.display = 'block';
    } else {
        adminTab.style.display = 'none';
    }
    
    // Populate category filters and dropdowns
    populateCategories();
    
    // Set max characters in form
    document.getElementById('max-chars').textContent = configData.maxLength || 500;
    
    // Show/hide anonymous option
    if (configData.allowAnonymous) {
        document.getElementById('anonymous-container').style.display = 'flex';
    } else {
        document.getElementById('anonymous-container').style.display = 'none';
    }
    
    // Load petitions
    loadAllPetitions();
    loadMyPetitions();
    
    // If admin, load admin panel
    if (playerData.isAdmin) {
        loadAdminPetitions();
    }
    
    // Setup event listeners
    setupEventListeners();
}

// Populate category filters and dropdowns
function populateCategories() {
    const categoryFilter = document.getElementById('category-filter');
    const petitionCategory = document.getElementById('petition-category');
    
    // Clear existing options
    categoryFilter.innerHTML = '<option value="all">All Categories</option>';
    petitionCategory.innerHTML = '';
    
    // Add categories
    if (configData.categories && configData.categories.length > 0) {
        configData.categories.forEach(category => {
            const filterOption = document.createElement('option');
            filterOption.value = category;
            filterOption.textContent = category;
            categoryFilter.appendChild(filterOption);
            
            const formOption = document.createElement('option');
            formOption.value = category;
            formOption.textContent = category;
            petitionCategory.appendChild(formOption);
        });
    }
}

// Load active petitions
function loadAllPetitions() {
    const container = document.getElementById('active-petitions-list');
    container.innerHTML = '';
    
    const approvedPetitions = petitions.filter(petition => petition.status === 'approved' || petition.status === 'completed');
    
    if (approvedPetitions.length === 0) {
        container.innerHTML = '<div class="no-petitions">No petitions found</div>';
        return;
    }
    
    approvedPetitions.forEach(petition => {
        container.appendChild(createPetitionCard(petition));
    });
    
    // Apply current filters
    filterPetitions();
}

// Load user's petitions
function loadMyPetitions() {
    const container = document.getElementById('my-petitions-list');
    container.innerHTML = '';
    
    const myPetitions = petitions.filter(petition => petition.author_citizenid === playerData.citizenid);
    
    if (myPetitions.length === 0) {
        container.innerHTML = '<div class="no-petitions">You haven\'t created any petitions yet</div>';
        return;
    }
    
    myPetitions.forEach(petition => {
        container.appendChild(createPetitionCard(petition));
    });
}

// Load petitions for admin panel
function loadAdminPetitions() {
    const container = document.getElementById('admin-petitions-list');
    container.innerHTML = '';
    
    if (petitions.length === 0) {
        container.innerHTML = '<div class="no-petitions">No petitions found</div>';
        return;
    }
    
    petitions.forEach(petition => {
        container.appendChild(createPetitionCard(petition));
    });
    
    // Apply current filters
    filterAdminPetitions();
}

// Create a petition card element
function createPetitionCard(petition) {
    const card = document.createElement('div');
    card.className = 'petition-card';
    card.dataset.id = petition.id;
    
    const createdDate = new Date(petition.created_at);
    const formattedDate = `${createdDate.toLocaleDateString()} ${createdDate.toLocaleTimeString()}`;
    
    card.innerHTML = `
        <div class="petition-header">
            <div class="petition-title">${petition.title}</div>
            <div class="petition-category">${petition.category}</div>
        </div>
        <div class="petition-meta">
            <div>${petition.is_anonymous ? 'Anonymous' : petition.author_name}</div>
            <div>${formattedDate}</div>
            <div class="petition-status status-${petition.status}">${capitalizeFirstLetter(petition.status)}</div>
            <div class="petition-signatures">${petition.signature_count} / ${configData.requiredSignatures || 15} signatures</div>
        </div>
    `;
    
    // Add click event to open petition details
    card.addEventListener('click', function() {
        openPetitionDetails(petition.id);
    });
    
    return card;
}

// Open petition details modal
function openPetitionDetails(id) {
    // Fetch petition details from server
    fetch(`https://${GetParentResourceName()}/getPetitionDetails`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ id: id })
    })
    .then(resp => resp.json())
    .then(petition => {
        if (!petition) {
            showNotification('Petition not found', 'error');
            return;
        }
        
        currentPetition = petition;
        
        // Update modal content
        document.getElementById('modal-petition-title').textContent = petition.title;
        document.getElementById('modal-petition-category').textContent = petition.category;
        
        const createdDate = new Date(petition.created_at);
        document.getElementById('modal-petition-date').textContent = `Created on: ${createdDate.toLocaleDateString()}`;
        
        document.getElementById('modal-petition-author').textContent = `By: ${petition.is_anonymous ? 'Anonymous' : petition.author_name}`;
        document.getElementById('modal-petition-status').textContent = `Status: ${capitalizeFirstLetter(petition.status)}`;
        document.getElementById('modal-petition-status').className = `petition-status status-${petition.status}`;
        
        document.getElementById('modal-petition-signatures').textContent = `${petition.signature_count} / ${configData.requiredSignatures || 15} signatures`;
        document.getElementById('modal-petition-content').textContent = petition.content;
        
        // Update signatures list
        const signaturesList = document.getElementById('signatures-list');
        signaturesList.innerHTML = '';
        
        if (petition.signatures && petition.signatures.length > 0) {
            petition.signatures.forEach(sig => {
                const li = document.createElement('li');
                const signDate = new Date(sig.signed_at);
                li.textContent = `${sig.signer_name} - ${signDate.toLocaleDateString()}`;
                signaturesList.appendChild(li);
            });
        } else {
            signaturesList.innerHTML = '<li class="no-signatures">No signatures yet</li>';
        }
        
        // Show/hide sign button
        const signButton = document.getElementById('sign-petition-btn');
        if (petition.status === 'approved' && !petition.hasPlayerSigned && petition.author_citizenid !== playerData.citizenid) {
            signButton.style.display = 'block';
        } else {
            signButton.style.display = 'none';
        }
        
        // Show/hide delete button
        const deleteButton = document.getElementById('delete-petition-btn');
        if (petition.author_citizenid === playerData.citizenid || playerData.isAdmin) {
            deleteButton.style.display = 'block';
        } else {
            deleteButton.style.display = 'none';
        }
        
        // Show/hide admin actions
        const adminActions = document.getElementById('admin-actions');
        if (playerData.isAdmin) {
            adminActions.style.display = 'flex';
            
            // Configure admin buttons based on status
            const approveButton = document.getElementById('approve-petition-btn');
            const rejectButton = document.getElementById('reject-petition-btn');
            
            if (petition.status === 'pending') {
                approveButton.style.display = 'block';
                rejectButton.style.display = 'block';
            } else {
                approveButton.style.display = 'none';
                rejectButton.style.display = 'none';
            }
        } else {
            adminActions.style.display = 'none';
        }
        
        // Display the modal
        document.getElementById('petition-details-modal').style.display = 'block';
    })
    .catch(error => {
        console.error('Error fetching petition details:', error);
        showNotification('Failed to load petition details', 'error');
    });
}

// Filter petitions based on selected options
function filterPetitions() {
    const categoryFilter = document.getElementById('category-filter').value;
    const sortFilter = document.getElementById('sort-filter').value;
    const searchTerm = document.getElementById('search-input').value.toLowerCase();
    
    // Get all petition cards
    const petitionCards = document.querySelectorAll('#active-petitions-list .petition-card');
    let visibleCount = 0;
    
    petitionCards.forEach(card => {
        const petitionId = parseInt(card.dataset.id);
        const petition = petitions.find(p => p.id === petitionId);
        
        if (!petition) return;
        
        // Apply category filter
        const matchesCategory = categoryFilter === 'all' || petition.category === categoryFilter;
        
        // Apply search filter
        const matchesSearch = searchTerm === '' || 
                            petition.title.toLowerCase().includes(searchTerm) || 
                            petition.content.toLowerCase().includes(searchTerm) ||
                            petition.category.toLowerCase().includes(searchTerm) ||
                            (!petition.is_anonymous && petition.author_name.toLowerCase().includes(searchTerm));
        
        // Show/hide based on filters
        if (matchesCategory && matchesSearch) {
            card.style.display = 'block';
            visibleCount++;
        } else {
            card.style.display = 'none';
        }
    });
    
    // Show "no petitions" message if no results
    const noPetitionsMsg = document.querySelector('#active-petitions-list .no-petitions');
    if (noPetitionsMsg) {
        noPetitionsMsg.style.display = visibleCount === 0 ? 'block' : 'none';
    } else if (visibleCount === 0) {
        const msg = document.createElement('div');
        msg.className = 'no-petitions';
        msg.textContent = 'No petitions match your filters';
        document.getElementById('active-petitions-list').appendChild(msg);
    }
    
    // Apply sorting
    const list = document.getElementById('active-petitions-list');
    const items = Array.from(list.children).filter(child => child.className === 'petition-card' && child.style.display !== 'none');
    
    items.sort((a, b) => {
        const petitionA = petitions.find(p => p.id === parseInt(a.dataset.id));
        const petitionB = petitions.find(p => p.id === parseInt(b.dataset.id));
        
        if (sortFilter === 'newest') {
            return new Date(petitionB.created_at) - new Date(petitionA.created_at);
        } else if (sortFilter === 'oldest') {
            return new Date(petitionA.created_at) - new Date(petitionB.created_at);
        } else if (sortFilter === 'signatures') {
            return petitionB.signature_count - petitionA.signature_count;
        }
        
        return 0;
    });
    
    // Reappend items in sorted order
    items.forEach(item => list.appendChild(item));
}

// Filter admin petitions
function filterAdminPetitions() {
    const statusFilter = document.getElementById('admin-status-filter').value;
    
    // Get all petition cards
    const petitionCards = document.querySelectorAll('#admin-petitions-list .petition-card');
    let visibleCount = 0;
    
    petitionCards.forEach(card => {
        const petitionId = parseInt(card.dataset.id);
        const petition = petitions.find(p => p.id === petitionId);
        
        if (!petition) return;
        
        // Apply status filter
        const matchesStatus = statusFilter === 'all' || petition.status === statusFilter;
        
        // Show/hide based on filters
        if (matchesStatus) {
            card.style.display = 'block';
            visibleCount++;
        } else {
            card.style.display = 'none';
        }
    });
    
    // Show "no petitions" message if no results
    const noPetitionsMsg = document.querySelector('#admin-petitions-list .no-petitions');
    if (noPetitionsMsg) {
        noPetitionsMsg.style.display = visibleCount === 0 ? 'block' : 'none';
    } else if (visibleCount === 0) {
        const msg = document.createElement('div');
        msg.className = 'no-petitions';
        msg.textContent = 'No petitions match your filters';
        document.getElementById('admin-petitions-list').appendChild(msg);
    }
}

// Show notification
function showNotification(message, type = 'success') {
    const notification = document.getElementById('notification');
    notification.className = `notification ${type}`;
    
    document.getElementById('notification-message').textContent = message;
    
    notification.classList.add('show');
    
    setTimeout(() => {
        notification.classList.remove('show');
    }, 3000);
}

// Setup all event listeners
function setupEventListeners() {
    // Tab switching
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', function() {
            // Update active tab
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            this.classList.add('active');
            
            // Show corresponding tab content
            const tabId = this.dataset.tab;
            document.querySelectorAll('.tab-pane').forEach(pane => pane.classList.remove('active'));
            
            if (tabId === 'active') {
                document.getElementById('active-petitions').classList.add('active');
            } else if (tabId === 'my') {
                document.getElementById('my-petitions').classList.add('active');
            } else if (tabId === 'create') {
                document.getElementById('create-petition').classList.add('active');
            } else if (tabId === 'admin') {
                document.getElementById('admin-panel').classList.add('active');
            }
        });
    });
    
    // Close button
    document.getElementById('close-btn').addEventListener('click', function() {
        closeMenu();
    });
    
    // Filter events
    document.getElementById('category-filter').addEventListener('change', filterPetitions);
    document.getElementById('sort-filter').addEventListener('change', filterPetitions);
    document.getElementById('search-input').addEventListener('input', filterPetitions);
    
    // Admin filter events
    if (playerData.isAdmin) {
        document.getElementById('admin-status-filter').addEventListener('change', filterAdminPetitions);
    }
    
    // Close modal when clicking on X or outside
    document.querySelector('.close-modal').addEventListener('click', function() {
        document.getElementById('petition-details-modal').style.display = 'none';
    });
    
    window.addEventListener('click', function(event) {
        const modal = document.getElementById('petition-details-modal');
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    });
    
    // Character counter for petition content
    document.getElementById('petition-content').addEventListener('input', function() {
        const maxLength = configData.maxLength || 500;
        const currentLength = this.value.length;
        document.getElementById('char-count').textContent = currentLength;
        
        // Highlight red if over limit
        if (currentLength > maxLength) {
            document.getElementById('char-count').style.color = '#ef4444';
        } else {
            document.getElementById('char-count').style.color = '';
        }
    });
    
    // Form submission
    document.getElementById('petition-form').addEventListener('submit', function(event) {
        event.preventDefault();
        
        const title = document.getElementById('petition-title').value.trim();
        const content = document.getElementById('petition-content').value.trim();
        const category = document.getElementById('petition-category').value;
        const isAnonymous = document.getElementById('petition-anonymous').checked;
        
        // Validate
        if (title.length < 5 || title.length > 100) {
            showNotification('Title must be between 5 and 100 characters', 'error');
            return;
        }
        
        if (content.length < 10 || content.length > (configData.maxLength || 500)) {
            showNotification('Content must be between 10 and ' + (configData.maxLength || 500) + ' characters', 'error');
            return;
        }
        
        if (!category) {
            showNotification('Please select a category', 'error');
            return;
        }
        
        // Submit petition
        fetch(`https://${GetParentResourceName()}/createPetition`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                title,
                content,
                category,
                isAnonymous
            })
        })
        .then(resp => resp.json())
        .then(response => {
            if (response.success) {
                showNotification(response.message, 'success');
                
                // Clear form
                document.getElementById('petition-title').value = '';
                document.getElementById('petition-content').value = '';
                document.getElementById('petition-anonymous').checked = false;
                document.getElementById('char-count').textContent = '0';
                
                // Refresh petition lists
                refreshPetitions();
                
                // Switch to My Petitions tab
                document.querySelector('.tab[data-tab="my"]').click();
            } else {
                showNotification(response.message, 'error');
            }
        })
        .catch(error => {
            console.error('Error creating petition:', error);
            showNotification('Failed to create petition', 'error');
        });
    });
    
    // Sign petition button
    document.getElementById('sign-petition-btn').addEventListener('click', function() {
        if (!currentPetition) return;
        
        fetch(`https://${GetParentResourceName()}/signPetition`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: currentPetition.id
            })
        })
        .then(resp => resp.json())
        .then(response => {
            if (response.success) {
                showNotification(response.message, 'success');
                
                // Refresh petition details
                openPetitionDetails(currentPetition.id);
                
                // Refresh petition lists
                refreshPetitions();
            } else {
                showNotification(response.message, 'error');
            }
        })
        .catch(error => {
            console.error('Error signing petition:', error);
            showNotification('Failed to sign petition', 'error');
        });
    });
    
    // Delete petition button
    document.getElementById('delete-petition-btn').addEventListener('click', function() {
        if (!currentPetition) return;
        
        if (!confirm('Are you sure you want to delete this petition?')) {
            return;
        }
        
        fetch(`https://${GetParentResourceName()}/deletePetition`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: currentPetition.id
            })
        })
        .then(resp => resp.json())
        .then(response => {
            if (response.success) {
                showNotification(response.message, 'success');
                
                // Close modal
                document.getElementById('petition-details-modal').style.display = 'none';
                
                // Refresh petition lists
                refreshPetitions();
            } else {
                showNotification(response.message, 'error');
            }
        })
        .catch(error => {
            console.error('Error deleting petition:', error);
            showNotification('Failed to delete petition', 'error');
        });
    });
    
    // Admin approve button
    document.getElementById('approve-petition-btn').addEventListener('click', function() {
        if (!currentPetition || !playerData.isAdmin) return;
        
        fetch(`https://${GetParentResourceName()}/approvePetition`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: currentPetition.id
            })
        })
        .then(resp => resp.json())
        .then(response => {
            if (response.success) {
                showNotification(response.message, 'success');
                
                // Refresh petition details
                openPetitionDetails(currentPetition.id);
                
                // Refresh petition lists
                refreshPetitions();
            } else {
                showNotification(response.message, 'error');
            }
        })
        .catch(error => {
            console.error('Error approving petition:', error);
            showNotification('Failed to approve petition', 'error');
        });
    });
    
    // Admin reject button
    document.getElementById('reject-petition-btn').addEventListener('click', function() {
        if (!currentPetition || !playerData.isAdmin) return;
        
        fetch(`https://${GetParentResourceName()}/rejectPetition`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: currentPetition.id
            })
        })
        .then(resp => resp.json())
        .then(response => {
            if (response.success) {
                showNotification(response.message, 'success');
                
                // Refresh petition details
                openPetitionDetails(currentPetition.id);
                
                // Refresh petition lists
                refreshPetitions();
            } else {
                showNotification(response.message, 'error');
            }
        })
        .catch(error => {
            console.error('Error rejecting petition:', error);
            showNotification('Failed to reject petition', 'error');
        });
    });
    
    // Handle keyboard events
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            const modal = document.getElementById('petition-details-modal');
            if (modal.style.display === 'block') {
                modal.style.display = 'none';
            } else {
                closeMenu();
            }
        }
    });
}

// Helper function to refresh petitions
function refreshPetitions() {
    // Get updated petition data from server
    fetch(`https://${GetParentResourceName()}/getPetitions`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    })
    .then(resp => resp.json())
    .then(updatedPetitions => {
        petitions = updatedPetitions;
        
        // Reload petition lists
        loadAllPetitions();
        loadMyPetitions();
        
        if (playerData.isAdmin) {
            loadAdminPetitions();
        }
    })
    .catch(error => {
        console.error('Error refreshing petitions:', error);
    });
}

// Close menu and clean up
function closeMenu() {
    // Send NUI callback to close the menu
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    })
    .then(resp => resp.json())
    .then(() => {
        // Hide the container
        document.getElementById('petition-container').style.display = 'none';
        
        // Reset active tab
        document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
        document.querySelector('.tab[data-tab="active"]').classList.add('active');
        
        // Reset tab content
        document.querySelectorAll('.tab-pane').forEach(pane => pane.classList.remove('active'));
        document.getElementById('active-petitions').classList.add('active');
        
        // Hide modal if open
        document.getElementById('petition-details-modal').style.display = 'none';
    })
    .catch(error => {
        console.error('Error closing menu:', error);
    });
}

// Helper function to capitalize first letter
function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}
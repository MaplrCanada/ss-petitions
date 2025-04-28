// html/script.js
let maxTitleLength = 50;
let maxDescLength = 500;
let selectedPetitionId = null;
let currentPetitions = [];
let currentFilter = 'all';

// Utility Functions
function formatTimestamp(timestamp) {
    const date = new Date(timestamp * 1000);
    const now = new Date();
    const diff = Math.floor((now - date) / 1000);
    
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)} minutes ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} hours ago`;
    if (diff < 604800) return `${Math.floor(diff / 86400)} days ago`;
    
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return date.toLocaleDateString(undefined, options);
}

function showNotification(message, type = 'info') {
    const notification = document.getElementById('notification');
    const notificationText = document.getElementById('notification-text');
    
    notificationText.textContent = message;
    notification.classList.add('show');
    
    setTimeout(() => {
        notification.classList.remove('show');
    }, 3000);
}

// Player Petition Menu
function initPetitionMenu(data) {
    // Set max lengths
    maxTitleLength = data.maxTitle;
    maxDescLength = data.maxDesc;
    document.getElementById('title-max').textContent = maxTitleLength;
    document.getElementById('desc-max').textContent = maxDescLength;
    
    // Load categories
    const categorySelect = document.getElementById('petition-category');
    categorySelect.innerHTML = '';
    
    data.categories.forEach(category => {
        const option = document.createElement('option');
        option.value = category;
        option.textContent = category;
        categorySelect.appendChild(option);
    });
    
    // Update my petitions list
    updateMyPetitionsList(data.petitions);
    
    // Show the menu
    document.getElementById('petition-menu').classList.remove('hidden');
}

function updateMyPetitionsList(petitions) {
    const petitionsList = document.querySelector('#my-petitions .petitions-list');
    
    if (petitions.length === 0) {
        petitionsList.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-inbox"></i>
                <p>No petitions found</p>
            </div>
        `;
        return;
    }
    
    petitionsList.innerHTML = '';
    
    // Sort by timestamp (newest first)
    petitions.sort((a, b) => b.timestamp - a.timestamp);
    
    petitions.forEach(petition => {
        const petitionElement = document.createElement('div');
        petitionElement.className = 'petition-item';
        petitionElement.innerHTML = `
            <div class="petition-header">
                <div class="petition-title">${petition.title}</div>
                <div class="petition-status status-${petition.status}">${petition.status}</div>
            </div>
            <div class="petition-meta">
                <div><i class="fas fa-tag"></i> ${petition.category}</div>
                <div><i class="fas fa-clock"></i> ${formatTimestamp(petition.timestamp)}</div>
            </div>
        `;
        
        // Show petition details on click
        petitionElement.addEventListener('click', () => {
            const detailTitle = petition.title;
            const detailDate = formatTimestamp(petition.timestamp);
            const detailStatus = petition.status;
            const detailCategory = petition.category;
            const detailDescription = petition.description;
            
            showNotification(`Viewing petition: ${detailTitle}`);
        });
        
        petitionsList.appendChild(petitionElement);
    });
}

// Admin Panel
function initAdminPanel(data) {
    currentPetitions = data.petitions;
    updateAdminPetitionsList(data.petitions);
    document.getElementById('admin-panel').classList.remove('hidden');
}

function updateAdminPetitionsList(petitions) {
    const petitionsList = document.querySelector('#admin-panel .petitions-list');
    
    if (petitions.length === 0) {
        petitionsList.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-inbox"></i>
                <p>No petitions found</p>
            </div>
        `;
        return;
    }
    
    petitionsList.innerHTML = '';
    
    // Filter petitions based on current filter
    let filteredPetitions = petitions;
    if (currentFilter !== 'all') {
        filteredPetitions = petitions.filter(petition => petition.status === currentFilter);
    }
    
    // Apply search filter if search box has content
    const searchText = document.getElementById('petition-search').value.toLowerCase();
    if (searchText) {
        filteredPetitions = filteredPetitions.filter(petition => 
            petition.title.toLowerCase().includes(searchText) || 
            petition.description.toLowerCase().includes(searchText) ||
            petition.playerName.toLowerCase().includes(searchText)
        );
    }
    
    if (filteredPetitions.length === 0) {
        petitionsList.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-search"></i>
                <p>No matching petitions found</p>
            </div>
        `;
        return;
    }
    
    filteredPetitions.forEach(petition => {
        const petitionElement = document.createElement('div');
        petitionElement.className = 'petition-item';
        if (selectedPetitionId === petition.id) {
            petitionElement.classList.add('active');
        }
        
        petitionElement.innerHTML = `
            <div class="petition-header">
                <div class="petition-title">${petition.title}</div>
                <div class="petition-status status-${petition.status}">${petition.status}</div>
            </div>
            <div class="petition-meta">
                <div><i class="fas fa-user"></i> ${petition.playerName}</div>
                <div><i class="fas fa-clock"></i> ${formatTimestamp(petition.timestamp)}</div>
            </div>
        `;
        
        // Show petition details on click
        petitionElement.addEventListener('click', () => {
            selectedPetitionId = petition.id;
            showPetitionDetails(petition);
            
            // Update active state
            document.querySelectorAll('.petition-item').forEach(el => el.classList.remove('active'));
            petitionElement.classList.add('active');
        });
        
        petitionsList.appendChild(petitionElement);
    });
}

function showPetitionDetails(petition) {
    // Hide empty state and show content
    document.querySelector('.petition-details .empty-state').classList.remove('active');
    document.querySelector('.petition-content').classList.remove('hidden');
    
    // Update details
    document.getElementById('detail-title').textContent = petition.title;
    document.getElementById('detail-submitter').textContent = petition.playerName;
    document.getElementById('detail-category').textContent = petition.category;
    document.getElementById('detail-date').textContent = formatTimestamp(petition.timestamp);
    document.getElementById('detail-description').textContent = petition.description;
    
    // Update status
    document.querySelectorAll('.status-option').forEach(option => {
        if (option.dataset.status === petition.status) {
            option.classList.add('active');
        } else {
            option.classList.remove('active');
        }
    });
    
    // Clear comment field
    document.getElementById('admin-comment').value = '';
    
    // Update comments
    const commentsList = document.getElementById('comments-list');
    
    if (petition.comments && petition.comments.length > 0) {
        commentsList.innerHTML = '';
        
        petition.comments.forEach(comment => {
            const commentElement = document.createElement('div');
            commentElement.className = 'comment';
            commentElement.innerHTML = `
                <div class="comment-header">
                    <div>${comment.author}</div>
                    <div>${formatTimestamp(comment.timestamp)}</div>
                </div>
                <div class="comment-text">${comment.text}</div>
            `;
            commentsList.appendChild(commentElement);
        });
    } else {
        commentsList.innerHTML = '<div class="empty-comments">No comments yet</div>';
    }
}

// NUI Message Handler
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'openPetitionMenu':
            initPetitionMenu(data);
            break;
        case 'openAdminPanel':
            initAdminPanel(data);
            break;
    }
});

// Event Listeners
document.addEventListener('DOMContentLoaded', function() {
    // Tabs
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            const tabId = tab.dataset.tab;
            
            // Update active tab
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            
            // Update active content
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            document.getElementById(tabId).classList.add('active');
        });
    });
    
    // Character counters
    const titleInput = document.getElementById('petition-title');
    const descInput = document.getElementById('petition-description');
    const titleCounter = document.getElementById('title-counter');
    const descCounter = document.getElementById('desc-counter');
    
    titleInput.addEventListener('input', () => {
        titleCounter.textContent = titleInput.value.length;
    });
    
    descInput.addEventListener('input', () => {
        descCounter.textContent = descInput.value.length;
    });
    
    // Close buttons
    document.getElementById('close-petition').addEventListener('click', () => {
        document.getElementById('petition-menu').classList.add('hidden');
        fetch('https://ss-petition/closePetitionUI', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    });
    
    document.getElementById('close-admin').addEventListener('click', () => {
        document.getElementById('admin-panel').classList.add('hidden');
        fetch('https://ss-petition/closePetitionUI', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    });
    
    // Submit petition form
    document.getElementById('petition-form').addEventListener('submit', (e) => {
        e.preventDefault();
        
        const title = titleInput.value.trim();
        const category = document.getElementById('petition-category').value;
        const description = descInput.value.trim();
        
        if (!title) {
            showNotification('Please enter a petition title', 'error');
            return;
        }
        
        if (!description) {
            showNotification('Please enter a petition description', 'error');
            return;
        }
        
        // Submit petition
        fetch('https://ss-petition/submitPetition', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                title,
                category,
                description
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                showNotification(data.message, 'success');
                titleInput.value = '';
                descInput.value = '';
                titleCounter.textContent = '0';
                descCounter.textContent = '0';
                
                // Refresh the petitions list
                fetch('https://ss-petition/refreshPetitions', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ isAdmin: false })
                })
                .then(response => response.json())
                .then(data => {
                    updateMyPetitionsList(data.petitions);
                });
            } else {
                showNotification(data.message, 'error');
            }
        });
    });
    
    // Status options
    document.querySelectorAll('.status-option').forEach(option => {
        option.addEventListener('click', () => {
            document.querySelectorAll('.status-option').forEach(opt => opt.classList.remove('active'));
            option.classList.add('active');
        });
    });
    
    // Update petition button
    document.getElementById('update-petition').addEventListener('click', () => {
        if (!selectedPetitionId) return;
        
        const activeStatus = document.querySelector('.status-option.active').dataset.status;
        const comment = document.getElementById('admin-comment').value.trim();
        
        fetch('https://ss-petition/updatePetition', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                petitionId: selectedPetitionId,
                status: activeStatus,
                comment
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                showNotification(data.message, 'success');
                
                // Refresh the petitions list
                fetch('https://ss-petition/refreshPetitions', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ isAdmin: true })
                })
                .then(response => response.json())
                .then(data => {
                    currentPetitions = data.petitions;
                    updateAdminPetitionsList(data.petitions);
                    
                    // Update petition details if still selected
                    const updatedPetition = data.petitions.find(p => p.id === selectedPetitionId);
                    if (updatedPetition) {
                        showPetitionDetails(updatedPetition);
                    }
                });
            } else {
                showNotification(data.message, 'error');
            }
        });
    });
    
    // Admin filters
    document.querySelectorAll('.filter').forEach(filter => {
        filter.addEventListener('click', () => {
            document.querySelectorAll('.filter').forEach(f => f.classList.remove('active'));
            filter.classList.add('active');
            
            currentFilter = filter.dataset.filter;
            updateAdminPetitionsList(currentPetitions);
        });
    });
    
    // Search box
    document.getElementById('petition-search').addEventListener('input', (e) => {
        updateAdminPetitionsList(currentPetitions);
    });
});

// Close on ESC key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        document.getElementById('petition-menu').classList.add('hidden');
        document.getElementById('admin-panel').classList.add('hidden');
        
        fetch('https://ss-petition/closePetitionUI', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }
});
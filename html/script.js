// Main variables
let petitionsData = [];
let currentPetition = null;
let playerData = null;
let currentView = 'pending';
let isAdmin = false;
let themeColors = {};
let maxPetitionLength = 500;
let requiredSignatures = 25;

// Initialize NUI
$(document).ready(function() {
    // Listen for message from client
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.action === 'openPetition') {
            // Set theme colors if provided
            if (data.config && data.config.theme) {
                themeColors = data.config.theme;
                applyTheme();
            }
            
            // Set petition settings
            if (data.config) {
                if (data.config.maxLength) maxPetitionLength = data.config.maxLength;
                if (data.config.requiredSignatures) {
                    requiredSignatures = data.config.requiredSignatures;
                    $('#required-signatures').text(requiredSignatures);
                }
                $('#max-chars').text(maxPetitionLength);
            }
            
            // Store player data
            playerData = data.playerInfo;
            
            // Check if admin
            isAdmin = data.isAdmin || false;
            toggleAdminElements();
            
            // Load petitions data
            petitionsData = data.petitions || [];
            filterAndRenderPetitions();
            
            // Show UI
            $('body').fadeIn(300);
        }
    });
    
    // Apply initial event listeners
    setupEventListeners();
});

// Apply theme colors
function applyTheme() {
    // Create CSS variables
    const root = document.documentElement;
    if (themeColors.primary) root.style.setProperty('--primary-color', themeColors.primary);
    if (themeColors.secondary) root.style.setProperty('--secondary-color', themeColors.secondary);
    if (themeColors.accent) root.style.setProperty('--accent-color', themeColors.accent);
    if (themeColors.background) root.style.setProperty('--bg-color', themeColors.background);
    if (themeColors.text) root.style.setProperty('--text-color', themeColors.text);
}

// Toggle admin elements visibility
function toggleAdminElements() {
    if (isAdmin) {
        $('.admin-only').show();
    } else {
        $('.admin-only').hide();
    }
}

// Setup all event listeners
function setupEventListeners() {
    // Close button
    $('#close-btn').on('click', function() {
        closeUI();
    });
    
    // Escape key to close
    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            closeUI();
        }
    });
    
    // Navigation buttons
    $('#pending-btn').on('click', function() {
        $('.nav-buttons button').removeClass('active');
        $(this).addClass('active');
        currentView = 'pending';
        filterAndRenderPetitions();
    });
    
    $('#approved-btn').on('click', function() {
        $('.nav-buttons button').removeClass('active');
        $(this).addClass('active');
        currentView = 'approved';
        filterAndRenderPetitions();
    });
    
    $('#my-petitions-btn').on('click', function() {
        $('.nav-buttons button').removeClass('active');
        $(this).addClass('active');
        currentView = 'my';
        filterAndRenderPetitions();
    });
    
    // Create petition button
    $('#create-btn').on('click', function() {
        showSection('create-petition');
    });
    
    // Admin panel button
    $('#admin-btn').on('click', function() {
        showSection('admin-panel');
        renderAdminPetitions('pending');
    });
    
    // Search input
    $('#search-input').on('input', function() {
        filterAndRenderPetitions();
    });
    
    // Character counter
    $('#petition-content').on('input', function() {
        const length = $(this).val().length;
        $('#char-count').text(length);
        
        // Visual feedback
        if (length > maxPetitionLength * 0.8) {
            $('#char-count').css('color', '#f39c12');
        } else {
            $('#char-count').css('color', '');
        }
    });
    
    // Cancel petition button
    $('#cancel-petition').on('click', function() {
        showSection('petitions-list');
        clearCreateForm();
    });
    
    // Submit petition button
    $('#submit-petition').on('click', function() {
        submitPetition();
    });
    
    // Back to list button
    $('#back-to-list').on('click', function() {
        showSection('petitions-list');
    });
    
    // Sign petition button
    $('#sign-petition').on('click', function() {
        if ($(this).hasClass('signed')) return;
        signPetition();
    });
    
    // Admin tabs
    $('#pending-review-tab').on('click', function() {
        $('.admin-tabs button').removeClass('active');
        $(this).addClass('active');
        renderAdminPetitions('pending');
    });
    
    $('#all-petitions-tab').on('click', function() {
        $('.admin-tabs button').removeClass('active');
        $(this).addClass('active');
        renderAdminPetitions('all');
    });
    
    // Admin back button
    $('#admin-back').on('click', function() {
        $('.admin-detail').addClass('hidden');
        $('.admin-petitions').removeClass('hidden');
    });
    
    // Admin action buttons
    $('#admin-approve').on('click', function() {
        adminAction('approve');
    });
    
    $('#admin-reject').on('click', function() {
        adminAction('reject');
    });
}

// Show a specific section
function showSection(sectionId) {
    $('.section').removeClass('active');
    $(`#${sectionId}`).addClass('active');
}

// Filter and render petitions based on current view and search
function filterAndRenderPetitions() {
    const searchTerm = $('#search-input').val().toLowerCase();
    let filteredPetitions = [];
    
    switch(currentView) {
        case 'pending':
            filteredPetitions = petitionsData.filter(p => p.status === 'pending');
            break;
        case 'approved':
            filteredPetitions = petitionsData.filter(p => p.status === 'approved');
            break;
        case 'my':
            filteredPetitions = petitionsData.filter(p => p.author_id === playerData.citizenid);
            break;
        default:
            filteredPetitions = petitionsData;
    }
    
    // Apply search filter if needed
    if (searchTerm) {
        filteredPetitions = filteredPetitions.filter(p => 
            p.title.toLowerCase().includes(searchTerm) || 
            p.content.toLowerCase().includes(searchTerm)
        );
    }
    
    renderPetitions(filteredPetitions);
}

// Render petitions list
function renderPetitions(petitions) {
    const container = $('.petitions-container');
    container.empty();
    
    if (petitions.length === 0) {
        $('.no-petitions').removeClass('hidden');
    } else {
        $('.no-petitions').addClass('hidden');
        
        petitions.forEach(petition => {
            const card = $(`
                <div class="petition-card" data-id="${petition.id}">
                    <span class="status ${petition.status}">${capitalizeFirstLetter(petition.status)}</span>
                    <h3>${petition.title}</h3>
                    <p>${truncateText(petition.content, 100)}</p>
                    <div class="meta">
                        <span>${formatDate(petition.created_at)}</span>
                        <div class="signatures">
                            <i class="fas fa-signature"></i>
                            <span>${petition.signatures.length} / ${requiredSignatures}</span>
                        </div>
                    </div>
                </div>
            `);
            
            card.on('click', function() {
                const petitionId = $(this).data('id');
                viewPetitionDetails(petitionId);
            });
            
            container.append(card);
        });
    }
}

// View petition details
function viewPetitionDetails(petitionId) {
    const petition = petitionsData.find(p => p.id === petitionId);
    if (!petition) return;
    
    currentPetition = petition;
    
    // Set details
    $('#detail-title').text(petition.title);
    $('#detail-status').text(capitalizeFirstLetter(petition.status)).attr('class', 'status ' + petition.status);
    $('#detail-author').text(petition.author_name);
    $('#detail-date').text(formatDate(petition.created_at));
    $('#detail-signatures').text(petition.signatures.length + ' of ' + requiredSignatures);
    $('#detail-content').text(petition.content);
    
    // Admin comment
    if (petition.admin_comment) {
        $('#detail-admin-comment').text(petition.admin_comment);
        $('#admin-comment').removeClass('hidden');
    } else {
        $('#admin-comment').addClass('hidden');
    }
    
    // Render signatures
    renderSignatures(petition.signatures);
    
    // Check if player already signed
    const alreadySigned = petition.signatures.some(s => s.citizenId === playerData.citizenid);
    
    // Update sign button
    if (alreadySigned || petition.status !== 'pending' || petition.author_id === playerData.citizenid) {
        $('#sign-petition').addClass('signed').text('Already Signed');
        if (petition.status !== 'pending') {
            $('#sign-petition').text('Petition Closed');
        }
        if (petition.author_id === playerData.citizenid) {
            $('#sign-petition').text('Your Petition');
        }
    } else {
        $('#sign-petition').removeClass('signed').text('Sign Petition');
    }
    
    showSection('view-petition');
}

// Render signatures list
function renderSignatures(signatures) {
    const container = $('#signatures-list');
    container.empty();
    
    if (signatures.length === 0) {
        container.append('<p>No signatures yet.</p>');
    } else {
        signatures.forEach(signature => {
            container.append(`
                <div class="signature-item">
                    <span>${signature.name}</span>
                    <span>${formatDate(signature.date)}</span>
                </div>
            `);
        });
    }
}

// Submit a new petition
function submitPetition() {
    const title = $('#petition-title').val().trim();
    const content = $('#petition-content').val().trim();
    
    // Validation
    if (!title) {
        // Show error
        return;
    }
    
    if (!content) {
        // Show error
        return;
    }
    
    // Send to client
    $.post('https://qb-petition/createPetition', JSON.stringify({
        title: title,
        content: content
    }));
    
    // Clear form and return to list
    clearCreateForm();
    showSection('petitions-list');
    
    // Refresh petitions after a delay
    setTimeout(refreshPetitions, 1000);
}

// Clear create petition form
function clearCreateForm() {
    $('#petition-title').val('');
    $('#petition-content').val('');
    $('#char-count').text('0');
}

// Sign a petition
function signPetition() {
    if (!currentPetition) return;
    
    $.post('https://qb-petition/signPetition', JSON.stringify({
        petitionId: currentPetition.id
    }));
    
    // Disable button temporarily
    $('#sign-petition').addClass('signed').text('Processing...');
    
    // Refresh after a delay
    setTimeout(refreshPetitions, 1000);
}

// Render admin petitions
function renderAdminPetitions(view) {
    const container = $('.admin-petitions');
    container.empty();
    $('.admin-detail').addClass('hidden');
    container.removeClass('hidden');
    
    let filteredPetitions;
    
    if (view === 'pending') {
        // Show petitions that need review (pending with enough signatures)
        filteredPetitions = petitionsData.filter(p => 
            p.status === 'pending' && p.signatures.length >= requiredSignatures
        );
    } else {
        // All petitions
        filteredPetitions = [...petitionsData];
    }
    
    if (filteredPetitions.length === 0) {
        container.append('<p class="no-petitions-message">No petitions to review.</p>');
    } else {
        filteredPetitions.forEach(petition => {
            const card = $(`
                <div class="admin-petition-card" data-id="${petition.id}">
                    <span class="status ${petition.status}">${capitalizeFirstLetter(petition.status)}</span>
                    <h3>${petition.title}</h3>
                    <p>By ${petition.author_name} on ${formatDate(petition.created_at)}</p>
                    <div class="signatures">
                        <i class="fas fa-signature"></i>
                        <span>${petition.signatures.length} signatures</span>
                    </div>
                </div>
            `);
            
            card.on('click', function() {
                viewAdminPetitionDetails($(this).data('id'));
            });
            
            container.append(card);
        });
    }
}

// View admin petition details
function viewAdminPetitionDetails(petitionId) {
    const petition = petitionsData.find(p => p.id === petitionId);
    if (!petition) return;
    
    currentPetition = petition;
    
    // Set details
    $('#admin-detail-title').text(petition.title);
    $('#admin-detail-author').text(petition.author_name);
    $('#admin-detail-date').text(formatDate(petition.created_at));
    $('#admin-detail-content').text(petition.content);
    $('#admin-detail-signatures').text(petition.signatures.length);
    
    // Clear comment field
    $('#admin-comment-input').val('');
    
    // Show detail view
    $('.admin-petitions').addClass('hidden');
    $('.admin-detail').removeClass('hidden');
    
    // Disable buttons if already handled
    if (petition.status !== 'pending') {
        $('#admin-approve, #admin-reject').prop('disabled', true);
        $('#admin-comment-input').val(petition.admin_comment || '').prop('disabled', true);
    } else {
        $('#admin-approve, #admin-reject').prop('disabled', false);
        $('#admin-comment-input').prop('disabled', false);
    }
}

// Admin action on petition
function adminAction(action) {
    if (!currentPetition) return;
    
    const comment = $('#admin-comment-input').val().trim();
    
    $.post('https://qb-petition/adminAction', JSON.stringify({
        petitionId: currentPetition.id,
        action: action,
        comment: comment
    }));
    
    // Return to admin list
    $('.admin-detail').addClass('hidden');
    $('.admin-petitions').removeClass('hidden');
    
    // Refresh after a delay
    setTimeout(() => {
        refreshPetitions();
        renderAdminPetitions('pending');
    }, 1000);
}

// Refresh petitions data
function refreshPetitions() {
    $.post('https://qb-petition/refreshPetitions', {}, function(data) {
        petitionsData = data.petitions;
        isAdmin = data.isAdmin;
        filterAndRenderPetitions();
        
        // Update current petition if viewing details
        if (currentPetition && $('#view-petition').hasClass('active')) {
            const updatedPetition = petitionsData.find(p => p.id === currentPetition.id);
            if (updatedPetition) {
                viewPetitionDetails(updatedPetition.id);
            }
        }
    });
}

// Close UI and send message to client
function closeUI() {
    $('body').fadeOut(300);
    $.post('https://qb-petition/closePetition', JSON.stringify({}));
}

// Helper Functions
function truncateText(text, maxLength) {
    if (text.length > maxLength) {
        return text.substring(0, maxLength) + '...';
    }
    return text;
}

function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}
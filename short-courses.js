// Hero Slider Logic
let currentSlide = 0;
const slides = document.querySelectorAll('.slide');

function nextSlide() {
    slides[currentSlide].classList.remove('active');
    currentSlide = (currentSlide + 1) % slides.length;
    slides[currentSlide].classList.add('active');
}
setInterval(nextSlide, 5000);

// Filter Logic
// Filter Logic
function filterCourses() {
    const schoolValue = document.getElementById('schoolFilter').value;
    const levelValue = document.getElementById('levelFilter').value;
    const statusValue = document.getElementById('statusFilter').value;

    const courses = document.querySelectorAll('.course-card');
    let visibleCount = 0;

    const today = new Date();

    courses.forEach(card => {
        const cardSchool = card.getAttribute('data-school');
        const cardLevel = card.getAttribute('data-level');
        const startDateStr = card.getAttribute('data-start-date');
        const durationMonths = parseInt(card.getAttribute('data-duration') || '0');

        // Determine Status
        let cardStatus = 'unknown';
        if (startDateStr) {
            const startDate = new Date(startDateStr);
            const endDate = new Date(startDate);
            endDate.setMonth(endDate.getMonth() + durationMonths);

            if (today < startDate) {
                cardStatus = 'coming-soon';
            } else if (today >= startDate && today <= endDate) {
                cardStatus = 'ongoing';
            } else {
                cardStatus = 'passed';
            }
        }

        // Check Matches
        const schoolMatch = (schoolValue === 'all' || schoolValue === cardSchool);
        const levelMatch = (levelValue === 'all' || levelValue === cardLevel);
        const statusMatch = (statusValue === 'all' || statusValue === cardStatus);

        if (schoolMatch && levelMatch && statusMatch) {
            card.style.display = 'flex';
            visibleCount++;
        } else {
            card.style.display = 'none';
        }
    });

    // Handle empty state
    const noResults = document.getElementById('noResults');
    if (noResults) {
        noResults.style.display = visibleCount === 0 ? 'block' : 'none';
    }
}

// FAQ Accordion Logic
document.addEventListener("DOMContentLoaded", function () {
    const allQuestions = document.querySelectorAll('.faq-section .faq-question');

    allQuestions.forEach(question => {
        question.addEventListener('click', function (e) {
            e.stopPropagation(); // Prevent bubbling issues

            const parentItem = this.closest('.faq-item, .faq-item-main');
            const answer = this.nextElementSibling;
            const isActive = parentItem.classList.contains('active');

            // Find the immediate container to close siblings ONLY at the same level
            const container = parentItem.parentElement;

            // 1. Close siblings at this level
            Array.from(container.children).forEach(sibling => {
                if (sibling !== parentItem && sibling.classList.contains('active')) {
                    sibling.classList.remove('active');
                    // 2. Recursive Cleanup: If closing a parent, close all children inside it
                    const childActiveItems = sibling.querySelectorAll('.active');
                    childActiveItems.forEach(child => child.classList.remove('active'));
                }
            });

            // 3. Toggle the clicked item
            parentItem.classList.toggle('active');
        });
    });
});

// Mobile Nav Functions (Same as index)
function openMobileNav() {
    const modal = document.getElementById('mobileNavModal');
    modal.classList.add('show');
    document.body.style.overflow = 'hidden';

    // Close when clicking the dark background
    modal.onclick = function (e) {
        if (e.target === modal) {
            closeMobileNav();
        }
    };
}

function closeMobileNav() {
    document.getElementById('mobileNavModal').classList.remove('show');
    document.body.style.overflow = 'auto';
}
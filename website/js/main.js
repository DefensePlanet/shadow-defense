/* ============================================
   Shadow Defense: Tales from the Pages
   Website JavaScript
   ============================================ */

document.addEventListener('DOMContentLoaded', () => {

    // --- Navbar scroll effect ---
    const navbar = document.getElementById('navbar');

    const handleScroll = () => {
        navbar.classList.toggle('scrolled', window.scrollY > 50);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();

    // --- Mobile nav toggle ---
    const navToggle = document.querySelector('.nav-toggle');
    const navLinks = document.querySelector('.nav-links');

    if (navToggle) {
        navToggle.addEventListener('click', () => {
            navLinks.classList.toggle('open');
            navToggle.classList.toggle('active');
        });

        // Close menu on link click
        navLinks.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                navLinks.classList.remove('open');
                navToggle.classList.remove('active');
            });
        });
    }

    // --- Smooth scroll for anchor links ---
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            const target = document.querySelector(anchor.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth' });
            }
        });
    });

    // --- Scroll reveal animation ---
    const revealElements = document.querySelectorAll('.reveal');

    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                revealObserver.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    revealElements.forEach(el => revealObserver.observe(el));

    // --- Stagger tower and level card animations ---
    const staggerCards = (selector) => {
        const cards = document.querySelectorAll(selector);
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const parent = entry.target.closest(selector.includes('tower') ? '.tower-grid' : '.level-grid');
                    if (parent) {
                        const siblings = parent.querySelectorAll(selector.split(' ').pop());
                        siblings.forEach((card, i) => {
                            setTimeout(() => card.classList.add('visible'), i * 100);
                        });
                    }
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.1 });

        if (cards.length > 0) {
            observer.observe(cards[0]);
        }
    };

    staggerCards('.tower-grid .tower-card');
    staggerCards('.level-grid .level-card');

    // --- Game loader ---
    const loadBtn = document.getElementById('load-game-btn');
    const gameFrame = document.getElementById('game-frame');
    const placeholder = document.getElementById('game-placeholder');

    if (loadBtn) {
        loadBtn.addEventListener('click', () => {
            // Point to the exported Godot game HTML file in the game/ directory
            const gamePath = 'game/index.html';

            // Check if game files exist by attempting to load
            gameFrame.onload = () => {
                placeholder.style.display = 'none';
                gameFrame.style.display = 'block';
            };

            gameFrame.onerror = () => {
                loadBtn.textContent = 'Game files not found';
                loadBtn.disabled = true;
                loadBtn.style.opacity = '0.5';
            };

            loadBtn.textContent = 'Loading...';
            loadBtn.disabled = true;
            gameFrame.src = gamePath;

            // Fallback: if no load event fires within 5s, show error
            setTimeout(() => {
                if (gameFrame.style.display === 'none') {
                    placeholder.querySelector('h3').textContent = 'Game Loading...';
                    placeholder.querySelector('p').textContent = 'If the game doesn\'t appear, the export files may not be in the game/ folder yet.';
                    loadBtn.style.display = 'none';
                }
            }, 5000);
        });
    }

    // --- Fullscreen button ---
    const fullscreenBtn = document.getElementById('fullscreen-btn');
    const gameContainer = document.getElementById('game-container');

    if (fullscreenBtn && gameContainer) {
        fullscreenBtn.addEventListener('click', () => {
            if (gameContainer.requestFullscreen) {
                gameContainer.requestFullscreen();
            } else if (gameContainer.webkitRequestFullscreen) {
                gameContainer.webkitRequestFullscreen();
            } else if (gameContainer.msRequestFullscreen) {
                gameContainer.msRequestFullscreen();
            }
        });
    }

    // --- Active nav link on scroll ---
    const sections = document.querySelectorAll('section[id]');
    const navAnchors = document.querySelectorAll('.nav-links a:not(.nav-cta)');

    const updateActiveNav = () => {
        const scrollPos = window.scrollY + 120;

        sections.forEach(section => {
            const top = section.offsetTop;
            const height = section.offsetHeight;
            const id = section.getAttribute('id');

            if (scrollPos >= top && scrollPos < top + height) {
                navAnchors.forEach(a => {
                    a.classList.toggle('active', a.getAttribute('href') === `#${id}`);
                });
            }
        });
    };

    window.addEventListener('scroll', updateActiveNav, { passive: true });

    // --- Mobile play hint ---
    const isMobile = /Android|iPhone|iPad|iPod|webOS|BlackBerry/i.test(navigator.userAgent)
        || (navigator.maxTouchPoints > 1);
    const mobileHint = document.getElementById('mobile-play-hint');
    if (isMobile && mobileHint) {
        mobileHint.style.display = 'block';
    }
});

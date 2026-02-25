/**
 * GH Schools · Payment Options — JS
 * Preserves all original logic + new UI enhancements
 */
(function () {
  'use strict';

  /* ============================================================
     1. URL PARAMS — read & populate summary card
     ============================================================ */
  const params = new URLSearchParams(window.location.search);
  const school  = params.get('school')  || '';
  const level   = params.get('level')   || '';
  const course  = params.get('course')  || '';
  const price   = params.get('price')   || '';

  // Populate summary card
  const summaryCourse = document.getElementById('summaryCourse');
  const summarySchool = document.getElementById('summarySchool');
  const summaryLevel  = document.getElementById('summaryLevel');
  const summaryPrice  = document.getElementById('summaryPrice');

  if (summaryCourse) summaryCourse.innerText = course || 'Not specified';
  if (summarySchool) summarySchool.innerText  = school || '—';
  if (summaryLevel)  summaryLevel.innerText   = level  || '—';
  // Strip any existing currency prefix (GHS/GHC) to avoid double prefix e.g. "GHS GHC 4,800"
  const cleanPrice = price ? price.replace(/^(GHS|GHC)\s*/i, '').trim() : '';
  if (summaryPrice)  summaryPrice.innerText = cleanPrice ? `GHS ${cleanPrice}` : 'GHS 0';


  /* ============================================================
     2. PAYSTACK — build forward URL to buyforms.html
     ============================================================ */
  const contLink = document.getElementById('paystackContinue');
  if (contLink) {
    const forward = new URL('buyforms.html', window.location.href);
    const fwdParams = new URLSearchParams(params.toString());
    fwdParams.set('channel', 'paystack');
    forward.search = fwdParams.toString();
    contLink.setAttribute('href', forward.toString());
  }


  /* ============================================================
     3. KOWRI / MOBILE MONEY — build forward URL to kowri-pay-now.html
     ============================================================ */
  const kowriBtn = document.getElementById('kowriPay');
  if (kowriBtn) {
    const kowriForward = new URL('kowri-pay-now.html', window.location.href);
    const kowriParams = new URLSearchParams(params.toString());
    kowriParams.set('channel', 'kowri');
    kowriForward.search = kowriParams.toString();
    kowriBtn.setAttribute('href', kowriForward.toString());
  }


  /* ============================================================
     4. REQUEST ASSISTANCE — original mailto logic preserved
     ============================================================ */
  const assistSpan = document.querySelector('.help-offline + div span');
  if (assistSpan) {
    assistSpan.style.cursor = 'pointer';
    assistSpan.addEventListener('click', () => {
      const subject = encodeURIComponent('Payment assistance request');
      const body    = encodeURIComponent(
        `Hello,\n\nI need assistance with a payment.\n\n` +
        `Course: ${course}\nSchool: ${school}\nLevel: ${level}\nAmount: GHS ${price}\n`
      );
      window.location.href = `mailto:fees@ghschools.online?subject=${subject}&body=${body}`;
    });
  }


  /* ============================================================
     5. CARD SELECTION VISUAL FEEDBACK
        Adds a brief "selected" ripple/glow before navigation
     ============================================================ */
  const cards = document.querySelectorAll('.channel-card');

  cards.forEach(card => {
    const btn = card.querySelector('.cta-button');
    if (!btn) return;

    btn.addEventListener('click', function (e) {
      // Skip if href is not yet set or is just '#'
      const href = btn.getAttribute('href');
      if (!href || href === '#') return;

      e.preventDefault();

      // Visual feedback — briefly highlight the card
      card.classList.add('card--selected');

      // Small delay for the animation, then navigate
      setTimeout(() => {
        window.location.href = href;
      }, 280);
    });
  });


  /* ============================================================
     6. NETWORK CHIP HOVER LABELS (mobile tap support)
     ============================================================ */
  const networkChips = document.querySelectorAll('.network-chip');
  networkChips.forEach(chip => {
    chip.addEventListener('touchstart', () => {
      chip.classList.add('chip--touched');
    });
    chip.addEventListener('touchend', () => {
      setTimeout(() => chip.classList.remove('chip--touched'), 400);
    });
  });


  /* ============================================================
     7. SUMMARY CARD — graceful empty state
     ============================================================ */
  if (!course && !school && !level && !price) {
    const summaryCard = document.getElementById('courseSummary');
    if (summaryCard) {
      summaryCard.style.opacity = '0.6';
      summaryCard.title = 'Course details not provided via URL parameters';
    }
  }

})();

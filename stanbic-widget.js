/**
 * GH Schools - Stanbic Kowri Standalone Widget
 * Version: 2.0.0
 *
 * KEY FIXES over v1:
 *  1. pay() now accepts onSuccess / onClose callbacks from _pendingPayCtx.
 *  2. _execute() no longer navigates away. Instead it either:
 *       a. Polls the kowri-status Edge Function until the payment settles, then
 *          fires onSuccess({ reference, status }) — so the dashboard can save
 *          the payment to Supabase and generate a receipt exactly like Paystack.
 *       b. If the Edge Function returns a checkoutUrl it opens it in a popup
 *          (not a redirect) and polls for completion in the background.
 *  3. On close / cancel, onClose() is fired so any locked buttons are released.
 *  4. On page load, if a Kowri return_reference is present in the URL (from a
 *     popup redirect), the opener's onSuccess is called and the popup closes.
 *  5. Phone input formatting and network detection are preserved unchanged.
 */

const StanbicWidget = {
    supabase: null,
    amount: 0,
    feeType: '',
    feeBreakdown: '',
    detectedNetwork: '',
    _onSuccess: null,
    _onClose: null,
    _pollTimer: null,
    _pollPopup: null,

    // Prefix mapping for Ghana Networks
    PREFIX_MAP: {
        '24': 'MTN', '54': 'MTN', '55': 'MTN', '59': 'MTN',
        '20': 'Telecel', '50': 'Telecel',
        '26': 'AirtelTigo', '56': 'AirtelTigo', '57': 'AirtelTigo',
    },

    /**
     * Initializes the widget and injects required styles/HTML.
     * Must be called once after the page loads.
     */
    init(supabaseClient) {
        this.supabase = supabaseClient;
        this._injectStyles();
        this._injectHTML();
        this._checkReturnFromPopup();
    },

    /**
     * Public method to trigger the payment modal.
     * Config: { amount, feeType, feeBreakdown, onSuccess, onClose }
     * onSuccess(response) — called with { reference, status:'success' }
     * onClose()           — called when the student dismisses without paying
     */
    pay(config) {
        if (!this.supabase) {
            console.error("StanbicWidget: Supabase client not initialized.");
            if (config.onClose) config.onClose();
            return;
        }

        this.amount      = config.amount || 0;
        this.feeType     = config.feeType || "Direct Payment";
        this.feeBreakdown = config.feeBreakdown || "";
        this._onSuccess  = config.onSuccess  || null;
        this._onClose    = config.onClose    || null;

        const amtEl = document.getElementById('sw-amount');
        if (amtEl) amtEl.textContent = `GHS ${Number(this.amount).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;

        const modal = document.getElementById('sw-modal');
        if (modal) modal.style.display = 'flex';

        const phoneEl = document.getElementById('sw-phone');
        if (phoneEl) phoneEl.value = '';

        const msgEl = document.getElementById('sw-msg');
        if (msgEl) msgEl.textContent = '';

        this._updateBadge(null);
        this._setBtn('Authorize Payment', false);
        this._clearError();

        // Pre-fill phone from localStorage if available
        try {
            const storedPhone = localStorage.getItem('studentPhone') || '';
            if (storedPhone && phoneEl) {
                phoneEl.value = storedPhone;
                this._handleInput(phoneEl);
            }
        } catch(e) {}
    },

    // ─── Close / cancel ──────────────────────────────────────────────────────

    _close() {
        const modal = document.getElementById('sw-modal');
        if (modal) modal.style.display = 'none';
        this._stopPolling();
        if (typeof this._onClose === 'function') {
            this._onClose();
            this._onClose = null;
        }
        this._onSuccess = null;
    },

    // ─── Input formatting & network detection ────────────────────────────────

    _handleInput(inp) {
        const digits = inp.value.replace(/\D/g, '').slice(0, 10);

        // Format: 024 000 0000
        let fmt = digits;
        if (digits.length > 6) fmt = digits.slice(0,3) + ' ' + digits.slice(3,6) + ' ' + digits.slice(6);
        else if (digits.length > 3) fmt = digits.slice(0,3) + ' ' + digits.slice(3);
        inp.value = fmt;

        const msgEl = document.getElementById('sw-msg');
        if (digits.length >= 3) {
            const prefix = digits.slice(1, 3);
            this.detectedNetwork = this.PREFIX_MAP[prefix] || '';
            this._updateBadge(this.detectedNetwork);
            if (msgEl) {
                msgEl.textContent = this.detectedNetwork ? '✓ Network Detected' : '⚠ Unknown network — check number';
                msgEl.style.color = this.detectedNetwork ? '#00C48C' : '#FF4D4F';
            }
        } else {
            this.detectedNetwork = '';
            this._updateBadge(null);
            if (msgEl) msgEl.textContent = '';
        }
    },

    _updateBadge(network) {
        const badge = document.getElementById('sw-badge');
        const label = document.getElementById('sw-label');
        if (!badge || !label) return;
        if (network) {
            badge.style.display = 'flex';
            label.textContent = `${network} DETECTED`;
        } else {
            badge.style.display = 'none';
        }
    },

    // ─── Execute payment ─────────────────────────────────────────────────────

    async _execute() {
        const phone = (document.getElementById('sw-phone')?.value || '').replace(/\D/g, '');

        if (phone.length < 10) { this._showError("Please enter a valid 10-digit phone number."); return; }
        if (!this.detectedNetwork) { this._showError("Network not recognised — check the number and try again."); return; }

        this._setBtn('Connecting to Stanbic…', true);
        this._clearError();

        const payload = {
            amount:       this.amount,
            feeType:      this.feeType,
            feeBreakdown: this.feeBreakdown,
            phone,
            network:      this.detectedNetwork,
            studentId:    (localStorage.getItem('studentId') || 'GUEST').toUpperCase(),
            studentName:  localStorage.getItem('studentName')  || 'Student',
            studentEmail: localStorage.getItem('studentEmail') || '',
            department:   localStorage.getItem('studentDepartment') || '',
            level:        localStorage.getItem('studentLevel') || '',
            academicYear: localStorage.getItem('academicYear') || '',
            // Tell the Edge Function to redirect back here after Kowri auth
            returnUrl: window.location.origin + window.location.pathname
        };

        try {
            const { data, error } = await this.supabase.functions.invoke('kowri-initiate', { body: payload });
            if (error) throw new Error(error.message || JSON.stringify(error));

            if (!data) throw new Error('No response from payment server.');

            // ── Case 1: direct approval (Edge Function approved synchronously) ──
            if (data.status === 'success' || data.approved === true) {
                const ref = data.reference || data.transactionId || data.transaction_id || ('KOWRI-' + Date.now());
                this._succeed({ reference: ref, status: 'success', raw: data });
                return;
            }

            // ── Case 2: checkoutUrl returned — open in popup, poll for result ──
            if (data.checkoutUrl || data.checkout_url || data.paymentUrl || data.payment_url) {
                const url = data.checkoutUrl || data.checkout_url || data.paymentUrl || data.payment_url;
                const txRef = data.reference || data.transactionId || data.transaction_id || ('KOWRI-' + Date.now());

                // Store context so the popup return handler can reach it
                try {
                    sessionStorage.setItem('sw_pending_ref', txRef);
                    sessionStorage.setItem('sw_pending_fee', this.feeType);
                } catch(e) {}

                this._setBtn('Waiting for authorisation…', true);
                this._showInfo('A Stanbic/Kowri authorisation page has opened. Complete the payment there, then return here.');

                // Open popup — prefer popup so the dashboard stays alive
                const popup = window.open(url, 'kowri_payment',
                    'width=520,height=680,scrollbars=yes,resizable=yes,toolbar=no,menubar=no');

                if (popup) {
                    this._pollPopup = popup;
                    this._startPolling(txRef);
                } else {
                    // Popup blocked — fall back to same-tab redirect
                    // Save all the context so _checkReturnFromPopup() can restore it
                    try {
                        sessionStorage.setItem('sw_redirect_ref', txRef);
                        sessionStorage.setItem('sw_redirect_fee', this.feeType);
                        sessionStorage.setItem('sw_redirect_amount', String(this.amount));
                        sessionStorage.setItem('sw_redirect_breakdown', this.feeBreakdown);
                    } catch(e) {}
                    window.location.href = url;
                }
                return;
            }

            // ── Case 3: prompt-to-pay (no URL, student approves on handset) ──
            if (data.reference || data.transactionId || data.transaction_id) {
                const txRef = data.reference || data.transactionId || data.transaction_id;
                this._setBtn('Waiting — approve prompt on your phone…', true);
                this._showInfo('A payment prompt has been sent to ' + phone.replace(/(\d{3})(\d{3})(\d{4})/, '$1 $2 $3') + '. Approve it, then wait.');
                this._startPolling(txRef);
                return;
            }

            throw new Error('Unexpected response from payment server: ' + JSON.stringify(data));

        } catch (err) {
            console.error('[StanbicWidget] _execute error:', err);
            this._showError('Payment failed: ' + (err.message || String(err)));
            this._setBtn('Retry', false);
        }
    },

    // ─── Polling: check status until settled ─────────────────────────────────

    _startPolling(txRef) {
        let attempts = 0;
        const MAX    = 60;   // 5 minutes max (60 × 5s)
        const DELAY  = 5000; // 5 seconds

        const tick = async () => {
            attempts++;

            // If the student closed the popup manually, treat as cancel
            if (this._pollPopup && this._pollPopup.closed) {
                this._stopPolling();
                this._showError('Payment window was closed. If you completed the payment, please wait — your balance will update automatically.');
                this._setBtn('Retry', false);

                // Still poll a few more times in case payment went through
                let extraAttempts = 0;
                const extraTick = async () => {
                    extraAttempts++;
                    const settled = await this._checkStatus(txRef);
                    if (settled) return;
                    if (extraAttempts < 6) setTimeout(extraTick, 5000);
                };
                setTimeout(extraTick, 3000);
                return;
            }

            const settled = await this._checkStatus(txRef);
            if (settled) return;

            if (attempts >= MAX) {
                this._stopPolling();
                this._showError('Payment timed out. If you approved the prompt, please contact the Finance Office with reference: ' + txRef);
                this._setBtn('Close', false);
                return;
            }

            this._pollTimer = setTimeout(tick, DELAY);
        };

        this._pollTimer = setTimeout(tick, DELAY);
    },

    async _checkStatus(txRef) {
        try {
            const { data, error } = await this.supabase.functions.invoke('kowri-status', {
                body: { reference: txRef }
            });

            if (error) {
                console.warn('[StanbicWidget] status check error:', error);
                return false;
            }

            if (!data) return false;

            const status = String(data.status || data.payment_status || '').toLowerCase();

            if (status === 'success' || status === 'paid' || status === 'completed' || status === 'approved' || data.approved === true) {
                const ref = data.reference || data.transactionId || data.transaction_id || txRef;
                this._succeed({ reference: ref, status: 'success', raw: data });
                return true;
            }

            if (status === 'failed' || status === 'cancelled' || status === 'rejected' || status === 'expired') {
                this._stopPolling();
                this._showError('Payment was ' + status + '. Please try again.');
                this._setBtn('Try Again', false);
                return true; // stop polling
            }

            return false; // still pending
        } catch (e) {
            console.warn('[StanbicWidget] _checkStatus exception:', e);
            return false;
        }
    },

    _stopPolling() {
        if (this._pollTimer) { clearTimeout(this._pollTimer); this._pollTimer = null; }
        this._pollPopup = null;
    },

    // ─── Success path ─────────────────────────────────────────────────────────

    _succeed(response) {
        this._stopPolling();
        const modal = document.getElementById('sw-modal');
        if (modal) modal.style.display = 'none';

        // Clear the session storage flags
        try {
            sessionStorage.removeItem('sw_pending_ref');
            sessionStorage.removeItem('sw_pending_fee');
            sessionStorage.removeItem('sw_redirect_ref');
            sessionStorage.removeItem('sw_redirect_fee');
            sessionStorage.removeItem('sw_redirect_amount');
            sessionStorage.removeItem('sw_redirect_breakdown');
        } catch(e) {}

        if (typeof this._onSuccess === 'function') {
            const cb = this._onSuccess;
            this._onSuccess = null;
            this._onClose   = null;
            cb(response);
        }
    },

    // ─── Handle return from same-tab Kowri redirect ───────────────────────────

    _checkReturnFromPopup() {
        try {
            const params = new URLSearchParams(window.location.search);

            // Kowri typically appends ?reference=XXX&status=success on return
            const returnRef    = params.get('reference') || params.get('txref') || params.get('transaction_id');
            const returnStatus = (params.get('status') || params.get('payment_status') || '').toLowerCase();

            if (!returnRef) return;

            // Clean the URL so a refresh doesn't re-trigger
            const cleanUrl = window.location.origin + window.location.pathname;
            try { window.history.replaceState({}, '', cleanUrl); } catch(e) {}

            if (returnStatus === 'success' || returnStatus === 'paid' || returnStatus === 'completed') {
                // We returned from a redirect — fire onSuccess via the dashboard's
                // _pendingPayCtx which is still set in memory on page if this is an
                // SPA, or reconstitute from sessionStorage for a full redirect.
                const ctx = window._pendingPayCtx;
                if (ctx && typeof ctx.onSuccess === 'function') {
                    ctx.onSuccess({ reference: returnRef, status: 'success' });
                    window._pendingPayCtx = null;
                } else {
                    // Full redirect: we lost in-memory state.
                    // Show a banner and let the student know to refresh.
                    this._showReturnBanner(returnRef, returnStatus);
                }
            } else if (returnStatus === 'failed' || returnStatus === 'cancelled') {
                const ctx = window._pendingPayCtx;
                if (ctx && typeof ctx.onClose === 'function') ctx.onClose();
                window._pendingPayCtx = null;
            }
        } catch(e) {
            console.warn('[StanbicWidget] _checkReturnFromPopup error:', e);
        }
    },

    _showReturnBanner(ref, status) {
        // Called after a full-page redirect return when in-memory state is gone.
        // Show a non-dismissable banner asking the student to reload.
        try {
            const banner = document.createElement('div');
            banner.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:99999;background:#00447C;color:#fff;padding:16px 24px;display:flex;align-items:center;gap:14px;font-family:sans-serif;font-size:14px;font-weight:600;box-shadow:0 4px 16px rgba(0,0,0,0.3);';
            banner.innerHTML = `
                <i class="fas fa-check-circle" style="font-size:20px;color:#34d399;flex-shrink:0;"></i>
                <div style="flex:1;">
                    <div>Payment received (Ref: <strong>${ref}</strong>). Reloading your dashboard…</div>
                </div>`;
            document.body.prepend(banner);
            setTimeout(() => window.location.reload(), 2500);
        } catch(e) {}
    },

    // ─── UI helpers ──────────────────────────────────────────────────────────

    _setBtn(label, disabled) {
        const btn = document.getElementById('sw-btn');
        if (!btn) return;
        btn.disabled = disabled;
        btn.innerHTML = disabled
            ? `<i class="fas fa-spinner fa-spin" style="margin-right:8px;"></i>${label}`
            : label;
        btn.style.opacity = disabled ? '0.75' : '1';
        btn.style.cursor  = disabled ? 'default' : 'pointer';
    },

    _showError(msg) {
        const el = document.getElementById('sw-error');
        if (el) { el.textContent = msg; el.style.display = 'block'; }
    },

    _showInfo(msg) {
        const el = document.getElementById('sw-info');
        if (el) { el.textContent = msg; el.style.display = 'block'; }
    },

    _clearError() {
        const el = document.getElementById('sw-error');
        if (el) { el.textContent = ''; el.style.display = 'none'; }
        const info = document.getElementById('sw-info');
        if (info) { info.textContent = ''; info.style.display = 'none'; }
    },

    // ─── DOM injection ────────────────────────────────────────────────────────

    _injectStyles() {
        if (document.getElementById('sw-styles')) return; // already injected
        const css = `
            #sw-modal {
                position: fixed; inset: 0;
                background: rgba(0,0,0,0.65);
                display: none;
                align-items: center;
                justify-content: center;
                z-index: 9999;
                font-family: 'Outfit', sans-serif;
                padding: 20px;
            }
            .sw-box {
                background: #fff;
                width: 100%;
                max-width: 420px;
                border-radius: 20px;
                overflow: hidden;
                box-shadow: 0 16px 48px rgba(0,0,0,0.35);
            }
            .sw-header {
                background: linear-gradient(135deg, #00447C 0%, #0066B2 100%);
                color: #fff;
                padding: 20px 24px;
                display: flex;
                align-items: center;
                justify-content: space-between;
            }
            .sw-header-left { display:flex; align-items:center; gap:12px; }
            .sw-header-icon {
                width: 40px; height: 40px;
                background: rgba(255,255,255,0.15);
                border-radius: 10px;
                display: flex; align-items: center; justify-content: center;
                font-size: 18px;
            }
            .sw-header-title { font-size: 15px; font-weight: 800; }
            .sw-header-sub   { font-size: 11px; opacity: 0.65; margin-top: 2px; }
            .sw-body { padding: 24px; }
            .sw-amt-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: #64748b; text-align: center; margin-bottom: 4px; }
            .sw-amt { font-size: 36px; font-weight: 900; color: #00447C; text-align: center; margin-bottom: 20px; letter-spacing: -0.5px; }
            .sw-field-label { font-size: 12px; font-weight: 700; color: #334155; margin-bottom: 8px; }
            .sw-input {
                width: 100%;
                padding: 14px 16px;
                border: 2px solid #e2e8f0;
                border-radius: 12px;
                font-size: 22px;
                text-align: center;
                outline: none;
                font-weight: 700;
                letter-spacing: 2px;
                color: #0f172a;
                transition: border-color 0.15s;
                box-sizing: border-box;
            }
            .sw-input:focus { border-color: #00447C; }
            .sw-badge {
                display: none;
                background: #EBF2F9;
                color: #00447C;
                padding: 8px 14px;
                border-radius: 10px;
                margin-top: 10px;
                font-size: 12px;
                font-weight: 800;
                justify-content: center;
                align-items: center;
                gap: 8px;
                border: 1.5px solid #b8d4f0;
            }
            #sw-msg {
                font-size: 12px;
                margin-top: 8px;
                font-weight: 700;
                min-height: 18px;
                text-align: center;
            }
            #sw-error {
                display: none;
                background: #fff1f2;
                border: 1.5px solid #fecdd3;
                color: #9f1239;
                border-radius: 10px;
                padding: 10px 14px;
                font-size: 13px;
                font-weight: 600;
                margin-top: 14px;
                text-align: center;
            }
            #sw-info {
                display: none;
                background: #eff6ff;
                border: 1.5px solid #bfdbfe;
                color: #1d4ed8;
                border-radius: 10px;
                padding: 10px 14px;
                font-size: 12.5px;
                font-weight: 600;
                margin-top: 14px;
                text-align: center;
                line-height: 1.5;
            }
            .sw-btn {
                width: 100%;
                padding: 15px;
                background: linear-gradient(135deg, #00447C 0%, #0066B2 100%);
                color: #fff;
                border: none;
                border-radius: 12px;
                font-size: 15px;
                font-weight: 800;
                cursor: pointer;
                margin-top: 20px;
                transition: opacity 0.15s;
                letter-spacing: 0.2px;
            }
            .sw-btn:hover:not(:disabled) { opacity: 0.9; }
            .sw-cancel-btn {
                width: 100%;
                padding: 11px;
                background: transparent;
                color: #64748b;
                border: 1.5px solid #e2e8f0;
                border-radius: 12px;
                font-size: 14px;
                font-weight: 600;
                cursor: pointer;
                margin-top: 10px;
                transition: all 0.15s;
            }
            .sw-cancel-btn:hover { background: #f8fafc; color: #334155; }
            .sw-divider { border: none; border-top: 1.5px solid #f1f5f9; margin: 18px 0 0; }
            .sw-secure { display:flex; align-items:center; justify-content:center; gap:6px; font-size:11px; color:#94a3b8; margin-top:14px; }
        `;
        const style = document.createElement('style');
        style.id = 'sw-styles';
        style.textContent = css;
        document.head.appendChild(style);
    },

    _injectHTML() {
        if (document.getElementById('sw-modal')) return; // already injected
        const div = document.createElement('div');
        div.innerHTML = `
            <div id="sw-modal">
                <div class="sw-box">
                    <div class="sw-header">
                        <div class="sw-header-left">
                            <div class="sw-header-icon">
                                <i class="fas fa-university"></i>
                            </div>
                            <div>
                                <div class="sw-header-title">Stanbic Bank MoMo</div>
                                <div class="sw-header-sub">Powered by Kowri · Secured by Stanbic</div>
                            </div>
                        </div>
                        <button style="cursor:pointer;background:rgba(255,255,255,0.1);border:none;color:#fff;width:34px;height:34px;border-radius:8px;font-size:18px;display:flex;align-items:center;justify-content:center;" onclick="StanbicWidget._close()" title="Cancel">&times;</button>
                    </div>
                    <div class="sw-body">
                        <div class="sw-amt-label">Amount to Pay</div>
                        <div class="sw-amt" id="sw-amount">GHS 0.00</div>

                        <div class="sw-field-label">Mobile Money Number</div>
                        <input id="sw-phone" class="sw-input" type="tel" placeholder="024 000 0000" inputmode="numeric" autocomplete="tel">

                        <div id="sw-badge" class="sw-badge">
                            <i class="fas fa-tower-broadcast"></i>
                            <span id="sw-label"></span>
                        </div>
                        <div id="sw-msg"></div>

                        <div id="sw-error"></div>
                        <div id="sw-info"></div>

                        <button id="sw-btn" class="sw-btn">Authorize Payment</button>
                        <button class="sw-cancel-btn" onclick="StanbicWidget._close()">Cancel</button>

                        <hr class="sw-divider">
                        <div class="sw-secure">
                            <i class="fas fa-lock"></i>
                            256-bit encrypted · Stanbic Bank Ghana
                        </div>
                    </div>
                </div>
            </div>`;
        document.body.appendChild(div);

        // Bind events
        document.getElementById('sw-phone').addEventListener('input', (e) => this._handleInput(e.target));
        document.getElementById('sw-btn').addEventListener('click',  () => this._execute());
    }
};

window.StanbicWidget = StanbicWidget;
/**
 * GH Schools - Stanbic Kowri Standalone Widget
 * Version: 1.0.0
 */

const StanbicWidget = {
    supabase: null,
    amount: 0,
    feeType: '',
    feeBreakdown: '',
    detectedNetwork: '',

    // Prefix mapping for Ghana Networks
    PREFIX_MAP: {
        '24': 'MTN', '54': 'MTN', '55': 'MTN', '59': 'MTN',
        '20': 'Telecel', '50': 'Telecel',
        '26': 'AirtelTigo', '56': 'AirtelTigo', '57': 'AirtelTigo',
    },

    /**
     * Initializes the widget and injects required styles/HTML
     */
    init(supabaseClient) {
        this.supabase = supabaseClient;
        this._injectStyles();
        this._injectHTML();
    },

    /**
     * Public method to trigger the payment modal
     */
    pay(config) {
        if (!this.supabase) {
            console.error("StanbicWidget: Supabase client not initialized.");
            return;
        }

        this.amount = config.amount || 0;
        this.feeType = config.feeType || "Direct Payment";
        this.feeBreakdown = config.feeBreakdown || "";

        document.getElementById('sw-amount').textContent = `GHS ${Number(this.amount).toFixed(2)}`;
        document.getElementById('sw-modal').style.display = 'flex';
        document.getElementById('sw-phone').value = '';
        this._updateBadge(null);
    },

    /**
     * Internal: Formats and detects network
     */
    _handleInput(inp) {
        const digits = inp.value.replace(/\D/g, '').slice(0, 10);
        
        // Formatting: 024 000 0000
        let fmt = digits;
        if (digits.length > 6) fmt = digits.slice(0,3) + ' ' + digits.slice(3,6) + ' ' + digits.slice(6);
        else if (digits.length > 3) fmt = digits.slice(0,3) + ' ' + digits.slice(3);
        inp.value = fmt;

        const msg = document.getElementById('sw-msg');
        if (digits.length >= 3) {
            const prefix = digits.slice(1, 3);
            this.detectedNetwork = this.PREFIX_MAP[prefix] || '';
            this._updateBadge(this.detectedNetwork);
            msg.textContent = this.detectedNetwork ? '✓ Network Detected' : 'Unknown Network';
            msg.style.color = this.detectedNetwork ? '#00C48C' : '#FF4D4F';
        } else {
            this.detectedNetwork = '';
            this._updateBadge(null);
            msg.textContent = '';
        }
    },

    _updateBadge(network) {
        const badge = document.getElementById('sw-badge');
        const label = document.getElementById('sw-label');
        if (network) {
            badge.style.display = 'flex';
            label.textContent = `${network} DETECTED`;
        } else {
            badge.style.display = 'none';
        }
    },

    /**
     * Gathers student info and calls the Edge Function
     */
    async _execute() {
        const phone = document.getElementById('sw-phone').value.replace(/\D/g, '');
        const btn = document.getElementById('sw-btn');

        if (phone.length < 10) { alert("Enter a valid phone number."); return; }
        if (!this.detectedNetwork) { alert("Network not recognized."); return; }

        btn.disabled = true;
        btn.innerHTML = 'Connecting to Stanbic...';

        // Automatically pick details from localStorage (Portal standard)
        const payload = {
            amount: this.amount,
            feeType: this.feeType,
            feeBreakdown: this.feeBreakdown,
            phone: phone,
            network: this.detectedNetwork,
            studentId: (localStorage.getItem('studentId') || "GUEST").toUpperCase(),
            studentName: localStorage.getItem('studentName') || "Student",
            studentEmail: localStorage.getItem('studentEmail') || "",
            department: localStorage.getItem('studentDepartment') || "",
            level: localStorage.getItem('studentLevel') || "",
            academicYear: localStorage.getItem('academicYear') || "",
            returnUrl: window.location.origin + window.location.pathname
        };

        try {
            const { data, error } = await this.supabase.functions.invoke('kowri-initiate', { body: payload });
            if (error) throw error;

            if (data.checkoutUrl) {
                window.location.href = data.checkoutUrl;
            }
        } catch (err) {
            alert("Payment failed to initialize: " + err.message);
            btn.disabled = false;
            btn.innerHTML = 'Authorize Payment';
        }
    },

    _injectStyles() {
        const css = `
            #sw-modal { position:fixed; inset:0; background:rgba(0,0,0,0.6); display:none; align-items:center; justify-content:center; z-index:9999; font-family:sans-serif; padding:20px; }
            .sw-box { background:#fff; width:100%; max-width:400px; border-radius:20px; overflow:hidden; box-shadow:0 10px 40px rgba(0,0,0,0.3); }
            .sw-header { background:#00447C; color:#fff; padding:20px; font-weight:bold; display:flex; justify-content:space-between; }
            .sw-body { padding:24px; text-align:center; }
            .sw-amt { font-size:32px; font-weight:900; color:#00447C; margin:10px 0 20px; }
            .sw-input { width:100%; padding:15px; border:2px solid #ddd; border-radius:12px; font-size:20px; text-align:center; outline:none; font-weight:bold; }
            .sw-badge { display:none; background:#EBF2F9; color:#00447C; padding:8px; border-radius:10px; margin-bottom:10px; font-size:12px; font-weight:800; justify-content:center; gap:8px; border:1px solid #00447C; }
            .sw-btn { width:100%; padding:16px; background:#00447C; color:#fff; border:none; border-radius:12px; font-size:16px; font-weight:bold; cursor:pointer; margin-top:20px; }
            .sw-close { cursor:pointer; background:none; border:none; color:#fff; font-size:20px; }
        `;
        const style = document.createElement('style');
        style.textContent = css;
        document.head.appendChild(style);
    },

    _injectHTML() {
        const html = `
            <div id="sw-modal">
                <div class="sw-box">
                    <div class="sw-header">
                        <span>Stanbic Bank MoMo</span>
                        <button class="sw-close" onclick="document.getElementById('sw-modal').style.display='none'">&times;</button>
                    </div>
                    <div class="sw-body">
                        <div style="font-size:12px; color:#666;">AMOUNT TO PAY</div>
                        <div class="sw-amt" id="sw-amount">GHS 0.00</div>
                        <div id="sw-badge" class="sw-badge">
                            <i class="fas fa-tower-broadcast"></i> <span id="sw-label"></span>
                        </div>
                        <input id="sw-phone" class="sw-input" type="tel" placeholder="024 000 0000">
                        <div id="sw-msg" style="font-size:12px; margin-top:8px; font-weight:bold;"></div>
                        <button id="sw-btn" class="sw-btn">Authorize Payment</button>
                    </div>
                </div>
            </div>
        `;
        const div = document.createElement('div');
        div.innerHTML = html;
        document.body.appendChild(div);

        // Bind events
        document.getElementById('sw-phone').oninput = (e) => this._handleInput(e.target);
        document.getElementById('sw-btn').onclick = () => this._execute();
    }
};

window.StanbicWidget = StanbicWidget;
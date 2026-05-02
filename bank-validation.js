/* bank-validation.js */

const BankValidationManager = {
    studentId: null,
    academicYear: null,
    feeSchedule: [],
    balances: {},
    availableCredits: [],
    selectedValidation: null,

    // Step 1: Inject Modal Structure into the page
    _injectHTML() {
        if (document.getElementById('bvStandaloneModal')) return;

        const html = `
            <div id="bvStandaloneModal" class="bv-modal-overlay">
                <div class="bv-modal-box">
                    <div class="bv-modal-header">
                        <div>
                            <div style="font-weight: 800; font-size: 16px;">Bank Validation</div>
                            <div style="font-size: 11px; opacity: 0.8;">Apply ECOBANK credit to your account</div>
                        </div>
                        <button class="bv-close-btn" onclick="BankValidationManager.close()">&times;</button>
                    </div>
                    <div id="bvModalContent" class="bv-modal-body">
                        <!-- Dynamic Content Loaded Here -->
                    </div>
                </div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', html);
    },

    // Step 2: Open and Initialize
    async open() {
        this._injectHTML();
        document.getElementById('bvStandaloneModal').classList.add('active');
        this.studentId = localStorage.getItem('studentId');
        
        if (!this.studentId) {
            this._renderError("Student ID not found. Please log in.");
            return;
        }

        this._renderLoading("Syncing account status...");
        await this._fetchRequiredData();
    },

    close() {
        document.getElementById('bvStandaloneModal').classList.remove('active');
    },

    _renderLoading(msg) {
        document.getElementById('bvModalContent').innerHTML = `
            <div style="text-align:center; padding:40px;">
                <div class="bv-loader"></div>
                <p style="font-size:13px; color:#666;">${msg}</p>
            </div>
        `;
    },

    _renderError(msg) {
        document.getElementById('bvModalContent').innerHTML = `
            <div style="text-align:center; padding:30px;">
                <i class="fas fa-exclamation-circle" style="font-size:40px; color:#EF4444; margin-bottom:15px;"></i>
                <p style="font-weight:600;">${msg}</p>
                <button class="bv-btn-primary" onclick="BankValidationManager.close()">Close</button>
            </div>
        `;
    },

    // Step 3: Fetch Data (Logic for Outstanding Balances)
    async _fetchRequiredData() {
        try {
            const studentLevel = localStorage.getItem('studentLevel') || '100';
            const cleanLvl = studentLevel.replace(/\D/g, '');

            // A. Get Latest Academic Year
            const { data: yrData } = await window.supabase.from('fee_schedules')
                .select('academic_year').order('academic_year', { ascending: false }).limit(1).maybeSingle();
            this.academicYear = yrData?.academic_year;

            // B. Get Unused Validations
            const { data: credits, error: crError } = await window.supabase.from('payments')
                .select('id, amount, transaction_ref, payment_date')
                .eq('student_id', this.studentId)
                .eq('ecobank_validation_status', 'unused')
                .eq('status', 'approved')
                .contains('source_payload', { bank: 'ECOBANK' });

            if (crError) throw crError;
            this.availableCredits = credits || [];

            if (this.availableCredits.length === 0) {
                this._renderError("No unused ECOBANK validations found for your account.");
                return;
            }

            // C. Get Fee Schedule & Payments (To calc outstanding)
            const [schRes, payRes] = await Promise.all([
                window.supabase.from('fee_schedules').select('amount, fee_type').eq('level', cleanLvl).eq('academic_year', this.academicYear),
                window.supabase.from('payments').select('amount, fee_type, source_payload').eq('student_id', this.studentId).eq('status', 'approved')
            ]);

            // Calculate True Balances
            const paidMap = { tuition: 0, src: 0, medical: 0, departmental: 0 };
            payRes.data.forEach(p => {
                const payload = (typeof p.source_payload === 'string') ? JSON.parse(p.source_payload) : (p.source_payload || {});
                if (payload.bank === 'ECOBANK') return; // Skip the source records

                const type = (p.fee_type || '').toLowerCase();
                if (type.includes('tuition')) paidMap.tuition += Number(p.amount);
                else if (type.includes('src')) paidMap.src += Number(p.amount);
                else if (type.includes('medical')) paidMap.medical += Number(p.amount);
                else if (type.includes('departmental')) paidMap.departmental += Number(p.amount);
            });

            this.balances = { tuition: 0, src: 0, medical: 0, departmental: 0 };
            schRes.data.forEach(f => {
                const type = (f.fee_type || '').toLowerCase();
                if (type.includes('tuition')) this.balances.tuition = Math.max(0, f.amount - paidMap.tuition);
                else if (type.includes('src')) this.balances.src = Math.max(0, f.amount - paidMap.src);
                else if (type.includes('medical')) this.balances.medical = Math.max(0, f.amount - paidMap.medical);
                else if (type.includes('departmental')) this.balances.departmental = Math.max(0, f.amount - paidMap.departmental);
            });

            this._renderSelectionUI();

        } catch (e) {
            console.error(e);
            this._renderError("Failed to sync account data.");
        }
    },

    // Step 4: Render UI
    _renderSelectionUI() {
        const creditOptions = this.availableCredits.map(c => 
            `<option value="${c.id}" data-amt="${c.amount}" data-ref="${c.transaction_ref}">GHS ${c.amount.toFixed(2)} (Ref: ...${c.transaction_ref.slice(-5)})</option>`
        ).join('');

        const feeItems = [
            { id: 'src', label: 'SRC Dues', amt: this.balances.src },
            { id: 'medical', label: 'Medical Dues', amt: this.balances.medical },
            { id: 'departmental', label: 'Dept Dues', amt: this.balances.departmental },
            { id: 'tuition', label: 'Tuition Fees', amt: this.balances.tuition }
        ].filter(f => f.amt > 1).map(f => `
            <label class="bv-fee-item">
                <input type="checkbox" name="bvFeeItem" value="${f.id}" onchange="BankValidationManager._updateSummary()">
                <div style="flex:1;">
                    <div style="font-weight:700; font-size:14px;">${f.label}</div>
                    <div style="font-size:12px; color:#6B7280;">Outstanding: GHS ${f.amt.toFixed(2)}</div>
                </div>
            </label>
        `).join('');

        document.getElementById('bvModalContent').innerHTML = `
            <div class="bv-select-group">
                <label class="bv-label">1. Select Credit</label>
                <select id="bvCreditSelect" class="bv-select" onchange="BankValidationManager._updateSummary()">
                    <option value="">Choose bank validation...</option>
                    ${creditOptions}
                </select>
            </div>
            <div class="bv-fee-group">
                <label class="bv-label">2. Apply to fees</label>
                ${feeItems || '<p style="font-size:13px; color:green;">All fees are fully paid!</p>'}
            </div>
            <div id="bvSummary" class="bv-summary-box" style="display:none;"></div>
            <button id="bvSubmitBtn" class="bv-btn-primary" disabled onclick="BankValidationManager.process()">Apply Credit Now</button>
        `;
    },

    _updateSummary() {
        const select = document.getElementById('bvCreditSelect');
        const valId = select.value;
        const checked = Array.from(document.querySelectorAll('input[name="bvFeeItem"]:checked')).map(i => i.value);
        const summary = document.getElementById('bvSummary');
        const btn = document.getElementById('bvSubmitBtn');

        if (!valId || checked.length === 0) {
            summary.style.display = 'none';
            btn.disabled = true;
            return;
        }

        const valAmt = parseFloat(select.options[select.selectedIndex].dataset.amt);
        let remaining = valAmt;
        const allocation = {};
        const priority = ['src', 'medical', 'departmental', 'tuition'];

        priority.forEach(key => {
            if (checked.includes(key)) {
                const owed = this.balances[key];
                const take = (key === 'tuition') ? remaining : Math.min(owed, remaining);
                if (take > 0.01) {
                    allocation[key] = take;
                    remaining -= take;
                }
            }
        });

        this.currentAllocation = allocation;
        this.selectedValidation = { id: valId, ref: select.options[select.selectedIndex].dataset.ref, amt: valAmt };

        summary.innerHTML = Object.entries(allocation).map(([k, v]) => 
            `<div style="display:flex; justify-content:space-between; font-size:13px; margin-bottom:4px;">
                <span>Apply to ${k.toUpperCase()}</span>
                <span style="font-weight:700;">GHS ${v.toFixed(2)}</span>
            </div>`
        ).join('') + `<div style="border-top:1px solid #ddd; margin-top:8px; padding-top:8px; font-weight:800; display:flex; justify-content:space-between;">
            <span>Total Applied</span>
            <span>GHS ${(valAmt - remaining).toFixed(2)}</span>
        </div>`;

        summary.style.display = 'block';
        btn.disabled = false;
    },

    // Step 5: Final Execution (Atomic Lock + Split)
    async process() {
        if (!confirm("Are you sure? This validation will be marked as used.")) return;

        const btn = document.getElementById('bvSubmitBtn');
        btn.disabled = true;
        btn.innerHTML = "Processing...";

        try {
            // A. Lock validation record
            const { data: lock, error: lockErr } = await window.supabase.from('payments')
                .update({ ecobank_validation_status: 'used' })
                .eq('id', this.selectedValidation.id)
                .eq('ecobank_validation_status', 'unused')
                .select();

            if (lockErr || !lock.length) throw new Error("Validation is no longer available.");

            // B. Create Split Records
            const childRows = Object.entries(this.currentAllocation).map(([type, amt]) => ({
                student_id: this.studentId,
                amount: Math.round(amt * 100) / 100,
                fee_type: type.toUpperCase(),
                transaction_ref: `BV-WIDGET-${this.selectedValidation.ref.slice(0,5)}-${type.toUpperCase()}-${Math.floor(Math.random()*1000)}`,
                receipt_number: `R-BV-${Date.now()}-${Math.floor(Math.random()*100)}`,
                status: 'approved',
                payment_date: new Date().toISOString(),
                source_table: 'bank_widget',
                source_payload: { validation_source: 'ECOBANK', parent_id: this.selectedValidation.id },
                academic_year: this.academicYear,
                ecobank_validation_status: 'used'
            }));

            const { error: insErr } = await window.supabase.from('payments').insert(childRows);
            if (insErr) throw insErr;

            alert("Payment successful! Your account has been updated.");
            this.close();
            
            // Trigger UI refresh if parent page has a refresh function
            if (typeof window.forceRefreshPayments === 'function') window.forceRefreshPayments();
            else window.location.reload();

        } catch (e) {
            alert(e.message || "An error occurred.");
            this.close();
        }
    }
};
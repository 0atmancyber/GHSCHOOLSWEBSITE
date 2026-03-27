// 1. Initialize Supabase Client
// Note: 'supabase' is the global object from the CDN script.
// We rename the client instance to 'supabaseClient' to avoid naming conflicts.
const SUPABASE_URL = "https://fyriapqeztevzkcaaiqw.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5cmlhcHFlenRldnprY2FhaXF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5OTgyNTcsImV4cCI6MjA3OTU3NDI1N30.Re3EZ2VXE6Z7qWhVlxV6yqqIWB8wj1b1wURNLZXpddY";

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: {
        headers: {
            Authorization: `Bearer ${SUPABASE_ANON_KEY}`
        }
    }
});

// 2. DOM Elements
const form = document.getElementById('payment-form');
const payBtn = document.getElementById('pay-btn');
const btnText = document.getElementById('btn-text');
const btnSpinner = document.getElementById('btn-spinner');
const errorBox = document.getElementById('error-box');
let paymentSubscription = null;
let paymentWaitTimeout = null;

function mapUserFriendlyError(rawMessage) {
    const message = String(rawMessage || '').trim();

    if (message.includes('Status: 511') || /not authorized for/i.test(message)) {
        return 'Payment provider authorization is not enabled for this merchant profile yet. Please contact support to enable debit authorization bypass for customer numbers.';
    }

    return message || 'An unexpected error occurred. Please try again.';
}

// 3. Handle Form Submission
form.addEventListener('submit', async (e) => {
    e.preventDefault();

    // Clear previous errors & Set Loading State
    errorBox.style.display = 'none';
    errorBox.textContent = '';
    setLoading(true);

    // Get Form Data
    const formData = {
        first_name: document.getElementById('first-name').value.trim(),
        last_name: document.getElementById('last-name').value.trim(),
        phone: document.getElementById('phone').value.trim(),
        email: document.getElementById('email').value.trim(),
        amount: document.getElementById('amount') ? document.getElementById('amount').value : '200'
    };

    try {
        // 4. Call Supabase Edge Function
        const { data, error } = await supabaseClient.functions.invoke('kowri-payment', {
            body: {
                action: 'initiate_payment', // Matches the backend check
                payload: formData
            }
        });

        // Handle function invocation errors
        if (error) {
            console.error("Function invocation error:", error);

            let detailedMessage = error.message || "Failed to connect to payment server";

            if (error.context && typeof error.context.json === 'function') {
                try {
                    const contextJson = await error.context.json();
                    if (contextJson && contextJson.error) {
                        detailedMessage = contextJson.error;
                    }
                } catch (_ignored) {
                    // Keep fallback message if context body cannot be parsed.
                }
            }

            throw new Error(detailedMessage);
        }

        // Check for custom errors returned by the function
        if (data && data.error) {
            console.error("Payment function returned error:", data.error);
            throw new Error(data.error);
        }

        // 5. Handle Success (USSD Prompt Sent)
        if (data && data.success) {
            console.log("Success:", data.message);
            const merchantOrderId = data.merchantOrderId;

            // Show success message to user (USSD Prompt)
            btnText.textContent = "Check Phone";
            errorBox.textContent = data.message;
            errorBox.style.display = 'block';
            errorBox.style.backgroundColor = '#d1ecf1'; // Information blue background
            errorBox.style.color = '#0c5460';
            errorBox.style.borderColor = '#bee5eb';

            // 6. Start listening for payment success via Realtime
            listenForPaymentSuccess(merchantOrderId);

        } else {
            throw new Error(data.error || "Payment initiation failed.");
        }

    } catch (err) {
        console.error("Payment Error:", err);
        errorBox.textContent = mapUserFriendlyError(err.message);
        errorBox.style.display = 'block';
        errorBox.style.backgroundColor = '#fee2e2'; // Error red
        errorBox.style.color = '#b91c1c';
        errorBox.style.borderColor = '#fecaca';
        setLoading(false);
    }
});

// Helper: Toggle Loading UI
function setLoading(isLoading) {
    if (isLoading) {
        payBtn.disabled = true;
        btnText.style.display = 'none';
        btnSpinner.style.display = 'block';
    } else {
        payBtn.disabled = false;
        btnSpinner.style.display = 'none';
        btnText.style.display = 'inline';
        btnText.textContent = 'Pay Now';
    }
}

// Helper: Listen for Payment Success via Realtime
function listenForPaymentSuccess(orderId) {
    console.log("Listening for payment completion for reference:", orderId);

    if (paymentSubscription) {
        paymentSubscription.unsubscribe();
    }

    if (paymentWaitTimeout) {
        clearTimeout(paymentWaitTimeout);
    }

    paymentSubscription = supabaseClient
        .channel('public:admission_payments')
        .on('postgres_changes', {
            event: 'INSERT',
            schema: 'public',
            table: 'admission_payments',
            filter: `reference_code=eq.${orderId}`
        }, (payload) => {
            console.log('Success Payload received:', payload);
            if (payload.new && payload.new.payment_status === 'paid') {
                handleSuccessfulTransaction();
                paymentSubscription.unsubscribe();
                paymentSubscription = null;
            }
        })
        .on('postgres_changes', {
            event: 'UPDATE',
            schema: 'public',
            table: 'admission_payments',
            filter: `reference_code=eq.${orderId}`
        }, (payload) => {
            console.log('Update Payload received:', payload);
            if (payload.new && payload.new.payment_status === 'paid') {
                handleSuccessfulTransaction();
                paymentSubscription.unsubscribe();
                paymentSubscription = null;
            }
        })
        .subscribe((status) => {
            if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
                console.error('Realtime channel issue:', status);
                errorBox.textContent = 'Payment is being processed, but realtime updates are unavailable. Please refresh in a moment to confirm status.';
                errorBox.style.display = 'block';
                errorBox.style.backgroundColor = '#fff3cd';
                errorBox.style.color = '#856404';
                errorBox.style.borderColor = '#ffeeba';
                setLoading(false);
            }
        });

    paymentWaitTimeout = setTimeout(() => {
        if (paymentSubscription) {
            paymentSubscription.unsubscribe();
            paymentSubscription = null;
        }
        errorBox.textContent = 'Payment request sent. If you have confirmed on phone but do not see success yet, please refresh this page shortly.';
        errorBox.style.display = 'block';
        errorBox.style.backgroundColor = '#fff3cd';
        errorBox.style.color = '#856404';
        errorBox.style.borderColor = '#ffeeba';
        setLoading(false);
    }, 120000);
}

function handleSuccessfulTransaction() {
    if (paymentWaitTimeout) {
        clearTimeout(paymentWaitTimeout);
        paymentWaitTimeout = null;
    }

    // Show success message
    errorBox.textContent = "Payment Successful! Redirecting...";
    errorBox.style.backgroundColor = '#d4edda'; // Green background
    errorBox.style.color = '#155724';
    errorBox.style.borderColor = '#c3e6cb';

    payBtn.style.backgroundColor = '#28a745';
    btnText.textContent = "Redirecting...";
    btnSpinner.style.display = 'none';
    btnText.style.display = 'inline';

    // Redirect after a short delay
    setTimeout(() => {
        window.location.href = "https://ghschools.edu.gh/";
    }, 2000);
}
// 1. Initialize Supabase Client
// Note: 'supabase' is the global object from the CDN script.
// We rename the client instance to 'supabaseClient' to avoid naming conflicts.
const SUPABASE_URL = "https://fyriapqeztevzkcaaiqw.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5cmlhcHFlenRldnprY2FhaXF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5OTgyNTcsImV4cCI6MjA3OTU3NDI1N30.Re3EZ2VXE6Z7qWhVlxV6yqqIWB8wj1b1wURNLZXpddY";

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// 2. DOM Elements
const form = document.getElementById('payment-form');
const payBtn = document.getElementById('pay-btn');
const btnText = document.getElementById('btn-text');
const btnSpinner = document.getElementById('btn-spinner');
const errorBox = document.getElementById('error-box');

// 3. Handle Form Submission
form.addEventListener('submit', async (e) => {
    e.preventDefault();

    // Clear previous errors & Set Loading State
    errorBox.style.display = 'none';
    errorBox.textContent = '';
    setLoading(true);

    // Get Form Data
    const formData = {
        first_name: document.getElementById('first-name').value,
        last_name: document.getElementById('last-name').value,
        phone: document.getElementById('phone').value,
        email: document.getElementById('email').value
    };

    try {
        // 4. Call Supabase Edge Function
        const { data, error } = await supabaseClient.functions.invoke('kowri-payment', {
            body: {
                action: 'initiate_payment', // Matches the backend check
                payload: formData
            }
        });

        if (error) throw new Error(error.message);

        // Check for custom errors returned by the function
        if (data && data.error) {
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
        errorBox.textContent = err.message || "An unexpected error occurred. Please try again.";
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
        // We don't necessarily want to re-enable immediately if waiting for USSD
    }
}

// Helper: Listen for Payment Success via Realtime
function listenForPaymentSuccess(orderId) {
    console.log("Listening for payment completion for reference:", orderId);

    const subscription = supabaseClient
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
                subscription.unsubscribe();
            }
        })
        .subscribe();
}

function handleSuccessfulTransaction() {
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
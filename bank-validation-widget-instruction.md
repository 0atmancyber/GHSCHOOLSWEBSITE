Bank Validation widget

How to use this anywhere in your project
Step A: Include the files in the <head> or before the closing </body> of any page.
<link rel="stylesheet" href="bank-validation.css">
<script src="bank-validation.js"></script>

Step B: Trigger it with a simple button click or link
<!-- Example: A button anywhere in the app -->
<button onclick="BankValidationManager.open()">
    Use Bank Validation
</button>


Questions for you:
Supabase Access: Does your project initialize the supabase client as a global variable (e.g., window.supabase)? My script assumes window.supabase is available.
Parent Page Logic: Does the dashboard or other pages have a specific "Refresh" function? I included a check for window.forceRefreshPayments() to update the dashboard without a page reload. Does that name work for you?



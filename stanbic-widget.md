This is a great architectural move. Converting the logic into a standalone widget makes it "plug-and-play" for admission pages, graduation portals, or any other school site.
We will create a single file: stanbic-widget.js. It will encapsulate the HTML Injection, Scoped CSS, Prefix Detection, and API Logic.
How to use the new Widget
On any page, you just need to include the script and call it like this:

StanbicWidget.init(supabaseClient); // Initialize once

// Trigger it when a button is clicked
StanbicWidget.pay({
  amount: 150.00,
  feeType: 'Admission Fee',
  feeBreakdown: 'Form Processing + ID Card'
});


Step 2: Integration
Now you can use this in any other page (e.g., admission.html, graduation.html).
1. Include the script:

<script src="stanbic-widget.js"></script>

2. Initialize and trigger:

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient('URL', 'KEY');

// Initialize the widget once when the page loads
StanbicWidget.init(supabase);

// Call this function whenever you want to start a payment
function startAdmissionPayment() {
    StanbicWidget.pay({
        amount: 200.00,
        feeType: 'Admission Form',
        feeBreakdown: '2026 Academic Intake Form'
    });
}



# Results Checker Feature

## Overview
A new **Results Checker** system has been implemented in the footer of `index.html` that allows students to check if their WASSCE grades qualify them for admission to GH SCHOOLS programs.

## Features

### 1. **Footer Button**
- Located in the footer section in a new "Check Your Results" column
- Styled with a gradient background (blue to purple) matching the site's design
- Displays as: "🔍 RESULTS CHECKER"

### 2. **Modal Interface**
When students click the button, a modern modal opens with:
- Clean, professional design with gradient header
- Easy-to-close button (X icon)
- Smooth animations on open/close

### 3. **Program Type Selection**
Students select between:
- **Diploma Program**: Formal academic award from GH SCHOOLS COLLEGE (2 years)
- **ICC Program**: Internal Certificate of Competence (1-2 years, more flexible)

### 4. **WASSCE Grade Input**
Students enter their WASSCE grades for core subjects:
- English Language
- Core Mathematics
- Social Studies
- Integrated Science

Each grade has a dropdown menu with options:
- A1 (Excellent)
- B2 (Very Good)
- B3 (Good)
- C4-C6 (Credit)
- D7 (Pass)
- E8 (Pass)
- F9 (Fail)
- None (No SHS)

### 5. **Eligibility Check**
The system calculates an average grade point and displays:

#### **Grade Point System:**
- A1 = 1 point (best)
- B2 = 2 points
- B3 = 3 points
- C4-C6 = 4-6 points
- D7 = 7 points
- E8 = 8 points
- F9 = 9 points (worst)
- None = 0 points

### 6. **Results Display**

#### **Excellent Grades (Average: 1-3 points)**
- ✓ Fully qualified for Diploma Program
- ✓ Fully qualified for ICC Program
- Access to all school departments
- Recommendation to choose Diploma for comprehensive training

#### **Good Grades (Average: 3-5 points)**
- ✓ Qualified for Diploma Program
- ✓ Qualified for ICC Program
- Both programs available without restriction

#### **Pass Grades (Average: 5-7 points)**
- ⚠️ Fully qualified for ICC Program
- ⚠️ Diploma Program may require specific assessment
- Students should contact admissions for program-specific requirements

#### **Fail Grades (Average: 7+ points)**
- Special consideration needed
- Recommended to contact admissions office
- Bridging/Foundation programs available
- Alternative pathways discussed case-by-case

#### **No SHS (All "None")**
- ✓ Fully qualified for ICC Program only
- ✗ Not eligible for Diploma Program
- ICC programs designed for students without SHS certification

## Technical Details

### HTML Structure
- Modal div with class `results-checker-modal`
- Grade input fields with IDs: `checkerEnglish`, `checkerMath`, `checkerSocial`, `checkerScience`
- Program selection radio buttons: `checkerDiploma`, `checkerICC`
- Results display section: `resultsDisplay` and `eligibilityMessage`

### CSS Classes
- `.results-checker-btn`: Footer button styling
- `.results-checker-modal`: Modal overlay
- `.results-checker-content`: Modal container
- `.results-checker-header`: Modal title bar
- `.grades-grid`: Grade input grid layout
- `.eligibility-success`: Success message styling (green)
- `.eligibility-warning`: Warning/info message styling (yellow/orange)

### JavaScript Functions
- `openResultsChecker()`: Opens the modal
- `closeResultsChecker()`: Closes the modal and resets form
- `selectProgramType(type)`: Selects program type
- `checkResultsEligibility()`: Validates and processes results
- `gradeToPoint(grade)`: Converts letter grade to numeric point
- `displayEligibilityResults()`: Shows the eligibility message
- `resetResultsCheckerForm()`: Clears all form inputs

## User Experience

1. **Student clicks "RESULTS CHECKER" button** in footer
2. **Modal opens** with program type selection
3. **Student selects program type** (Diploma or ICC)
4. **Student enters WASSCE grades** from dropdown menus
5. **Student clicks "Check Eligibility" button**
6. **System displays eligibility results** with:
   - Grade point average
   - Qualification status for selected program
   - List of entered grades
   - Recommendations
   - Call-to-action button to start application

## Mobile Responsiveness
- Modal adapts to smaller screens
- Grid layout changes from 2 columns to 1 column on mobile
- Touch-friendly interface with appropriate spacing
- Proper font sizing for readability

## Integration with Admission Process
- Results are for informational purposes only
- Does not affect actual admission decisions
- Students can proceed to full application at `admission.HTML`
- Admissions office reviews all applications individually

## Contact Information
Students can contact admissions through information displayed in results:
- Email: admissions@ghschools.online
- Phone: +233 20 462 2250 / +233 27 762 2250
- Landline: +233 30 242 4909

## Future Enhancements
- Integration with actual admissions database
- Email results to student
- Program-specific grade requirements
- Multiple WASSCE attempt tracking
- Scholarship eligibility checks

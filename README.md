# StudyBuddies

StudyBuddies is a student application designed to help students manage their assignments, organise study events, and connect with other students who share similar courses or interests.

The application was developed using Flutter for the frontend, FastAPI for the backend, and Supabase for storing application data.

## Program Startup

### Requirements

Before running the application, make sure you have the following installed:

- Python 3
- Flutter SDK
- An iOS simulator or connected device

### Environment Setup

Before running the application, set up the environment files for both the backend and frontend.

For the backend, create a `.env` file inside the `backend` folder using the provided `.env.example` file as a reference. Replace the placeholder values with the required Supabase and Brevo credentials.

The actual API keys are not included in the repository for security reasons.

For the frontend, create a `.env` file inside the `frontend` folder and add:

```env
API_BASE_URL=http://127.0.0.1:8000
```

If you are using a physical device, use your computer's local network IP address instead.

### Starting the Backend

Open a terminal in the project folder and run the following commands:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Keep this terminal running while using the application.

### Starting the Frontend

Open another terminal in the project folder and run:

```bash
cd frontend
flutter pub get
flutter run
```

Select the simulator or connected device you want to use if prompted.

## Application Features

### Login and Registration

The login and registration features allow students to create accounts and securely access StudyBuddies.

#### Login

- Log in using an AUT student email address and password.
- Validate login details and display appropriate error messages.
- Verify login using a one-time password (OTP) sent to the student's email when OTP verification is enabled.
- Resend OTP codes when needed, subject to resend limits.
- Remember the user's login session when reopening the application.
- Log out of the application securely.

#### Registration

- Create a new account using an AUT student email address and password.
- Validate registration details and check whether the email address is already registered.
- Display validation messages for invalid or incomplete information.
- Send a one-time password (OTP) to the registered email address for verification.
- Verify the OTP before completing the registration process.
- Save registered account details to the backend and Supabase.

#### Forgot Password

- Request a password reset using the registered email address.
- Receive a one-time password (OTP) by email to verify the password reset request.
- Verify the OTP before allowing the password to be reset.
- Set a new password after successful verification.
- Display appropriate validation and error messages for invalid OTP codes or password reset attempts.

### Scheduler

The scheduler allows students to manage their assignments and study events in one place.

- View upcoming assignments and study events.
- Select a date on the calendar to view scheduled items.
- Open assignments and events to view their details.
- Add, edit, and delete assignments or events.
- Reschedule events by changing their date and time.
- View assignments sorted by their due dates.
- Set reminders for assignments and study events.
- Receive local notifications for upcoming assignments and events.
- Tap notifications to open the related assignment or event.
- Assignment reminders are cancelled when the assignment is marked as completed.

### Assignment Management

Students can keep track of their assignments and update their progress.

- Set assignment priority to Low, Medium, or High.
- Update assignment status to Not Started, In Progress, or Completed.
- Save changes to Supabase and display them in the scheduler.

### Matchmaking

The matchmaking feature allows students to find other students who share similar courses or interests.

- View recommended students based on shared courses and interests.
- Swipe through student profile cards.
- Open profiles to view more information.
- Swipe right to show interest in a student.
- Swipe left to skip a student for the current session.
- Save students to Interested or Uninterested lists.
- Remove students from these lists to allow them to appear in recommendations again.
- Block students.

### Study Invitations and Connections

- Send study invitations from recommendation cards or the Interested list.
- View pending invitations and prevent duplicate invitations.
- Receive notifications when another student sends an invitation.
- View incoming invitations and choose to accept or decline them.
- View the number of incoming invitations on the Match tab.
- Receive notifications when a sent invitation is accepted.
- View accepted connections in Matched partners.
- Tap notifications to open Incoming invitations or Matched partners.

### Chat and Messaging

The chat feature allows connected students to communicate and manage their conversations within StudyBuddies.

- View conversations with other students.
- Send and receive messages.
- Edit and delete sent messages.
- View online status to check whether other students are active.
- Receive notifications when new messages arrive.
- Mark unread messages.
- Hide or block conversations from the conversation list.
- Control who can send messages based on messaging permissions.
- Open conversations and manage messages within the chat interface.

### Profile

Students can create and manage their profiles to share information with other students.

- Create profile information, including name, personal details, courses, interests, and preferences.
- Display and edit profile information.
- Add and edit spoken languages.

### Settings

Students can customise their StudyBuddies experience and manage their preferences.

- Enable or disable OTP verification during login.
- Set their study status to Available or Busy.
- View hidden or blocked conversations and unhide or unblock conversations.
- View blocked students and unblock students.

## Data Storage

StudyBuddies uses Supabase to store application data, including assignments, study events, assignment progress, reminders, student profiles, user settings, OTP verification records, matchmaking interests, study invitations, student connections, blocked users, chat conversations, messages, and message reports. 

Changes made within the application are saved to Supabase so they can be retrieved when needed.

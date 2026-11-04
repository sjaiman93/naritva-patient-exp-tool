# Naritva Patient Experience & Grievance Recovery Tool (V2)
### Naritva Women's Medical Studio (Ahmedabad, Gujarat)

A high-performance, trilingual (English / ગુજરાતી / हिन्दी) mobile web application designed for maternity, outpatient, and pediatric patient feedback, review draft generation, and real-time grievance escalation.

---

## 🌟 Key Features

1. **Upfront 3-Language Gate:** Instant switching between colloquial Ahmedabad Gujarati, Hindi, and English.
2. **3 Distinct Clinical Journeys:**
   - **🩺 OPD Checkup:** Fast 4-tap consultation feedback (< 20 seconds).
   - **🤱 Delivery / Admitted (IPD):** Structured multi-touchpoint discharge feedback (Labor room/OT, Day & Night nursing, In-house Pharmacy, Lab reports, Room hygiene, Discharge speed & Billing).
   - **👶 Pediatric Visit:** Child-focused doctor care, vaccination with "No vaccine today" option, and child-friendly waiting area.
3. **The "Sister / Friend" Cultural Trust Test:** High-signal referral metric (*"Would you suggest Naritva to your sister or friend?"*).
4. **Zero Review Gating:** Full compliance with Google Maps review policy and India's IS 19000:2022 standards. The Google button remains accessible across all ratings.
5. **Anti-Gatekeeping Reflection Engine:** Respectfully incorporates constructive feedback (e.g. wait times, pharmacy delays, waiting area crowding) into generated drafts so reviews remain genuine and credible.
6. **3-Tier Intelligent Triage & Grievance Interception:**
   - **Tier 1 (Positive):** Direct Google review draft.
   - **Tier 2 (Operational Friction):** Soft WhatsApp check-in with pre-filled ticket reference.
   - **Tier 3 (Clinical / Safety / "Not yet"):** Live reference tracking (`Ref #NRT-...`), PRO WhatsApp bridge, and in-person PRO desk escalation before discharge.
   - **Emergency Banner:** 24x7 Naritva Helpline (`7265-920-920`) prominently displayed for urgent clinical concerns.
7. **Daily Shift Roster:** Live attribution to on-duty doctors, sisters (female nurses), brothers (male nursing staff), and reception.
8. **Native Mobile UX:** Swipe-to-go-back gesture, browser history integration (`popstate`), and zero dependencies.

---

## 🚀 Quick Start (Local)

```bash
# Run standalone server
node server.js
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## ☁️ Deploying to Vercel

1. Push this repository to GitHub.
2. Log in to [Vercel](https://vercel.com) and click **"Add New Project"**.
3. Import this repository.
4. Framework Preset: **Other** (Static HTML).
5. Click **Deploy**. Vercel will provide an instant HTTPS URL (e.g. `naritva.vercel.app`).

---

## 🗄️ Connecting to Supabase

1. Open your [Supabase Dashboard](https://supabase.com).
2. Create a new project: `naritva-px`.
3. Go to the **SQL Editor** tab.
4. Copy and paste the contents of [`supabase-schema.sql`](./supabase-schema.sql) and click **Run**.
5. Tables created:
   - `patient_reviews` (PX analytics, doctor strength scores, constructive feedback)
   - `grievance_tickets` (Tier 2/3 incident tracking, SLA tracking, status: open/contacted/resolved)
   - `daily_roster` (Active daily doctor and nurse duty roster)

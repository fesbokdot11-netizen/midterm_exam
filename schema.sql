-- 1. Semester Submissions Table
CREATE TABLE IF NOT EXISTS semester_submissions (
  id TEXT PRIMARY KEY,
  scholar_id TEXT NOT NULL,
  academic_year TEXT NOT NULL,
  semester TEXT NOT NULL,
  gwa NUMERIC(3,2) NOT NULL,
  enrolled_units INT NOT NULL,
  failed_count INT NOT NULL,
  inc_count INT NOT NULL,
  drop_count INT NOT NULL,
  evidence_ref TEXT NOT NULL,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  verification_status TEXT DEFAULT 'Pending verification',
  verification_notes TEXT,
  compliance_result TEXT DEFAULT 'Pending',
  compliance_reasons TEXT[],
  renewal_decision TEXT DEFAULT 'Pending',
  decision_notes TEXT,
  CONSTRAINT unique_scholar_semester UNIQUE (scholar_id, academic_year, semester)
);

-- 2. Audit Logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  submission_id TEXT REFERENCES semester_submissions(id) ON DELETE CASCADE,
  actor TEXT NOT NULL,
  action_type TEXT NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  previous_state TEXT,
  new_state TEXT
);

-- 3. Enable Public Access for Zero-Login Testing
ALTER TABLE semester_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon select on submissions" ON semester_submissions FOR SELECT USING (true);
CREATE POLICY "Allow anon insert/update on submissions" ON semester_submissions FOR ALL USING (true);

CREATE POLICY "Allow anon select on audit" ON audit_logs FOR SELECT USING (true);
CREATE POLICY "Allow anon insert on audit" ON audit_logs FOR INSERT WITH CHECK (true);
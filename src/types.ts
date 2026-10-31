export interface UserProfile {
  name: string;
  email: string;
  phone: string;
  uid: string;
  selectedClass: string;
  subscription: string; // 'FREE' | 'PRO' | 'ACTIVE' | 'DEACTIVE'
  deviceInfo?: string;
  isLoggedIn: boolean;
}

export interface SheetRow {
  ID?: number | string;
  id?: number | string;
  Subject?: string;
  subject?: string;
  'Sub-subject'?: string;
  'sub-subject'?: string;
  'Sub_subject'?: string;
  Chapter?: string;
  chapter?: string;
  'Access Type'?: string;
  'Is-free'?: string;
  'is_free'?: string;
  'Drive-link-hin'?: string;
  'Drive_link_hin'?: string;
  'Drive-link-eng'?: string;
  'Drive_link_eng'?: string;
  'MCQ hin'?: string;
  'MCQ_hin'?: string;
  'MCQ eng'?: string;
  'MCQ_eng'?: string;
  'Option A hin'?: string;
  'Option_A_hin'?: string;
  'Option A eng'?: string;
  'Option_A_eng'?: string;
  'Option B hin'?: string;
  'Option_B_hin'?: string;
  'Option B eng'?: string;
  'Option_B_eng'?: string;
  'Option C hin'?: string;
  'Option_C_hin'?: string;
  'Option C eng'?: string;
  'Option_C_eng'?: string;
  'Option D hin'?: string;
  'Option_D_hin'?: string;
  'Option D eng'?: string;
  'Option_D_eng'?: string;
  'Answer'?: string;
  'answer'?: string;
  'Explanation hin'?: string;
  'Explanation_hin'?: string;
  'Explanation eng'?: string;
  'Explanation_eng'?: string;
  [key: string]: any;
}

export type StudyMode = 'mcq' | 'practice' | 'notes';

export interface QuizOption {
  letter: 'A' | 'B' | 'C' | 'D';
  text: string;
}

export interface QuizQuestionData {
  id: string | number;
  questionText: string;
  options: QuizOption[];
  correctLetter: string;
  explanation: string;
  raw: SheetRow;
}

export type NavigationScreen = 
  | { name: 'login' }
  | { name: 'boardSelect'; isSwitching?: boolean }
  | { name: 'classSelect' }
  | { name: 'dashboard' }
  | { name: 'subject'; mode: StudyMode }
  | { name: 'subSubject'; mode: StudyMode; subjectName: string }
  | { name: 'chapter'; mode: StudyMode; subjectName: string; subSubjectName: string }
  | { name: 'quiz'; subject: string; chapter: string; quizSetNumber: number }
  | { name: 'freeContent' }
  | { name: 'pdfViewer'; pdfUrl: string; title: string };

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://iyrmmabzasmfovohbgti.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5cm1tYWJ6YXNtZm92b2hiZ3RpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0NTIwNTMsImV4cCI6MjA5ODAyODA1M30.oGJpG8I1VDfjGGZ4vKciN6geee_vyIvdMsiY7pQCjx4';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

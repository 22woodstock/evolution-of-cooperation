-- 협력의 지도 — 생성형 AI 대결의 대화·이유 기록 테이블
-- Supabase 대시보드 → SQL Editor → New query 에 붙여 넣고 Run 한 번.
-- 여러 번 실행해도 안전하다.
--
-- 판 정보는 기존 sessions 에, 라운드별 선택은 기존 moves 에 그대로 들어간다.
--   sessions.opponent_strategy = 'LLM_CHAT'(대화 있는 판) 또는 'LLM_SILENT'(대화 없는 판)
--   sessions.rules_ver         = 'llm1_p1_<모델 이름>_t0.7_…'  (지시문 버전·모델·온도)
-- 이 테이블에는 AI의 이유, 주고받은 말, 응답 시간처럼 AI 판에만 있는 정보가 들어간다.

create table if not exists public.llm_turns (
  id             uuid primary key default gen_random_uuid(),
  session_id     uuid references public.sessions(id) not null,
  round_number   int  not null,
  condition      text not null check (condition in ('chat','silent')),
  model          text,            -- 예: exaone-3.5-7.8b-instruct
  prompt_ver     text,            -- 지시문 버전 (ai.html 의 LLM.promptVer)
  ai_choice      text check (ai_choice in ('C','D')),
  ai_reason      text,            -- AI가 밝힌 이유 (참가자에게는 판이 끝난 뒤 공개)
  ai_message     text,            -- AI가 참가자에게 한 말 (대화 있는 판만)
  human_message  text,            -- 참가자가 AI에게 한 말 (대화 있는 판만, 말 없이 넘기면 null)
  ai_latency_ms  int,             -- AI가 답하는 데 걸린 시간
  human_wait_ms  int,             -- 참가자가 고른 뒤 AI를 기다린 시간
  attempts       int,             -- 형식 오류로 다시 물은 횟수 포함 요청 수
  fallback       boolean,         -- 끝내 답을 못 해 기본 수(참가자의 지난 수)로 대신했는지
  raw_output     text,            -- AI의 원래 답 그대로
  created_at     timestamptz default now()
);

alter table public.llm_turns enable row level security;

-- 본인이 만든 판에만 넣을 수 있다. 읽기·수정·삭제 정책은 일부러 만들지 않는다.
drop policy if exists "본인 판의 llm_turns 삽입" on public.llm_turns;
create policy "본인 판의 llm_turns 삽입"
  on public.llm_turns for insert
  with check (
    exists (select 1 from public.sessions where id = session_id and user_id = auth.uid())
  );

notify pgrst, 'reload schema';

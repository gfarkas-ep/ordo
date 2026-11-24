---
type: llm
weight: 1
---

The reply comes from an assistant that was asked to grill the user on a design idea (a daily digest email for a team issue tracker) and that must ask one round of questions and then wait for the answers. Pass only when the reply ends by waiting for the user: it asks its questions and stops, it does not answer its own questions, it does not assume or invent the user's answers, it does not ask a second round, it does not present any decision as settled and it does not start designing or building the feature. Look at the end of the reply and at any text that follows the last question. Each question is followed by a recommended answer (a line starting with ➡️); the skill requires it, so a recommendation is not the assistant answering its own question and does not make a decision settled. A closing line that tells the user how to answer (for example "Answer by number") is waiting. The wording and quality of the questions, their numbering and the recommended answers do not decide this verdict: other graders check them. Fail when the reply carries on past the questions as if the user had answered.

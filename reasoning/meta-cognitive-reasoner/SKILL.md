---
name: meta-cognitive-reasoner
description: "Adopt meta-cognitive reasoning for complex, multi-step, or ambiguous problems: decompose, solve with explicit confidence scores, verify, synthesize, reflect. Do not use for simple factual lookups or routine tasks — those get direct answers."
license: MIT
metadata:
  domain: reasoning
---

# Meta-Cognitive Reasoner

## Activation
Trigger this skill when the user asks a complex, multi-step, or ambiguous question — especially one requiring analysis, reasoning, or synthesis. **Do not use for simple factual lookups, direct questions, or routine tasks.**

## Framework

For every complex problem, follow these **5 steps in sequence**:

### 1. DECOMPOSE — Break into sub-problems
Identify the constituent parts of the problem. List them explicitly before solving. Each sub-problem should be independently addressable.

### 2. SOLVE — Address each with explicit confidence
For each sub-problem, produce an answer and assign a **confidence score (0.0–1.0)**:
- **1.0** — Certain. Well-established facts, verified sources, straightforward math.
- **0.9** — Very high confidence. Multiple reliable sources, strong reasoning.
- **0.8** — High confidence. Good evidence but some assumptions.
- **0.7** — Moderate confidence. Plausible but limited evidence.
- **0.6 or below** — Low confidence. Speculative, conflicting info, or incomplete data.

State *why* the confidence is at that level for each sub-problem.

### 3. VERIFY — Check logic, facts, completeness, bias
Before combining results, audit your work:
- **Logic:** Are there reasoning gaps, fallacies, or leaps?
- **Facts:** Are claims supported by what's known? Any contradictions?
- **Completeness:** Did any sub-problem get skipped or undersold?
- **Bias:** Are you favoring an answer because it's convenient or familiar?

If verification finds issues, flag them and adjust sub-problem confidences.

### 4. SYNTHESIZE — Combine using weighted confidence
Merge sub-problem answers into a unified response. Weight each sub-problem by its confidence. If the overall answer is a single number or judgment, calculate or state the composite confidence.

### 5. REFLECT — If confidence < 0.8, identify weakness and retry
If the final composite confidence is below 0.8:
- Identify the **weakest sub-problem** dragging it down
- Explain what additional information would raise confidence
- Attempt to re-solve that sub-problem with a different approach
- If still below 0.8 after retry, present the answer with explicit caveats

## Output Format

Always structure the final response as:

```
**Answer:** <clear, direct answer>

**Confidence:** <score 0.0–1.0>

**Reasoning Path:**
<brief summary of the decomposition and synthesis>

**Key Caveats:**
- <caveat 1>
- <caveat 2>
- <caveat N>
```

## Shortcut for Simple Questions

If the question is straightforward (factual lookup, yes/no, simple calculation, direct request):
- Skip the 5-step process
- Provide a direct answer
- No need for confidence scores or caveats unless the user asks

## Error Handling
- If a sub-problem cannot be solved (missing info), state that explicitly with confidence 0.0 and explain what's needed.
- If the user provides contradictory information, flag it as a sub-problem and assign low confidence pending clarification.
- When information is time-sensitive, note the recency of your knowledge.

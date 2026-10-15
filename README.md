# AI-policy

This AI policy is aimed at people who understand that AI is a key
actor for better and faster work, but require control and quality.

This policy is for you if you answer yes to most of these questions:

- Do you often require strict contribution rules for your projects ?
- Do you spend more time micro-managing AI than actually working along side it ?
- Do you wish AI to be more like a devlopper teammate ?
- Do you want AI to not be fully autonomous or do you want to prevent it from making critical decisions on your behalf ?
- Do you spend too much time arguing with prompts with the AIs ?

What about these "feeling" questions: 

- Are you a compulsive perfectionist ?
- Do you feel like you struggle making AI understand you ?
- Do you feel like AI agents aren't following your rules or prompts ?
- Do you struggle understanding the AI's explaination ?

## Foreword

I'd like to take the time to talk about what I learned.

I always was the kind of person being obbsessed with understanding and learning
each step to achieve something.

I'm a slow software engineer because I spend a ridiculous amount of time
understanding everything.

Then, came AI.

I rememeber being frustrated with it from the start (GPT-2 era).

As time moved on, my frustration grew more and more.

I didn't know why it was the case, until I decided to actually
address the problem when I became a solo engineer, under hard deadlines.

This document is a statement around what I learned, and how to deal with it.

Here is the main take:

As AI codes more and more for you, you have to make choices about what you
control, and what you can afford to understand and learn deeply.

As Grant Sanderson, the host of 3blue1brown, said:
> [...] If I wanted to add more, I would suddently not understand it as well.
[source (at 357s)](https://youtu.be/0Ge3jKLDJaA?si=i6vjYFz5Tyvz41La&t=357)

Understanding doesn't scale well with fast building.
You either slow down, like I always did, or compromise on what you can afford
to understand.

I came to realize that, like Grant Sanderson, I am ok with letting go on
understanding everything when building for others.

AI work is now a new layer of abstraction.
A compromise on deep knowledge to increase productivity.

To cite Grant one last time:
> Are you learning in order to build? (Be the pug)
> Or are you building in order to learn? (Be the collie)
[source (at 466s)](https://youtu.be/0Ge3jKLDJaA?si=3koQanodRv3H5qcE&t=466)

## What is Agentic Coding ?

### The 4 Concepts of coding with AI Agents

Primary source of this section: [5 Concepts to Know for Coding with AI Agents (by IBM)](https://www.youtube.com/watch?v=hTAWHgQI4xg&t=53s)

The last concept is skipped, because it concerns the future of AI.

#### (1) The inflection point

##### 1a: AI shouldn't be used as autocomplete anymore

AI as autocomplete results more often in more time
fixing the AI output. Mostly because of it's limited knowledge scope,
lack of project context.[^1]

##### 2a: Prompting an autonomous agent is not enough

Autonomous AI agents do more things:
1. Code
2. Understanding the code base[^1]
3. Writting and Running tests
4. Branching and merging (git)

But it has one fatal flaw: you prompt and guide it.
You are not working along side AI, but use AI as a tool.
You code faster, but cannot multitask effectively.
You argue with AI, instead of woring along side it.

Autonomous agents gives the illusion that you have teammates, but you
instead micro-manage them. 

Do you work faster ? Yes.

Do you work more effectively ? Not necessarly.

Can you focus on other tasks while the AI running. Ask yourself if this ever
really was the case.

##### 2a: The pain point

Both of these concepts (AI as autocomplete or Autonomous AI agents) rely on
**prompt driven developpement** (aka, **vibecoding**), which is a pain point.

Prompting result in different outcomes and understandings
from model to models, even within the same 
ecosystem (e.g: claude sonnet and claude opus).
Additionnaly, it leads to fights with AI. Instead of fixing the code, you
ask the AI, by prompting yet again, to fix its mistakes.
These additional prompts conpounds ambiguity and bloats its context
window with discussions instead of useful data.

A solution to taht prompting and autocompleting issue is
**Spec Driven Developpement**, explained below.

[^1]: An **adjacent** concept [here](https://youtu.be/k2qls2LiBRc?si=QxgdpYl7Gc1s_MW9&t=620),
focusing on AI context window. The idea is similar: The AI have a limited view
of the whole project, and makes conceptual mistakes because of that.

#### (2) Implementation to conducting

AI already ships code faster than you.
AI already implements descrete code with greater quality than you.

So what do human developpers do ?

You conduct. **You are the architect**.

This is why, by the way, you don't want AI to make important decisions for you,
because you have better overview knowledge, and better contextual awareness
than it'll ever have (linking back to this [video](https://youtu.be/k2qls2LiBRc?si=QxgdpYl7Gc1s_MW9&t=620))

##### How to become the architect/conductor

- Define clear, unambiguous goals.
- Breakdown the work into milestones and tasks.
- Context engineering, we'll come back to that one.
- Manage tools, skills, MCPs and other RAG (Retrivial augmented generation) concepts.
- loop engineering
 
**Context engineering**:
This one is important.
LLMs have limitations. Their context window is limited,
They often forget due to the [lost in the middle problem](https://dev.to/thousand_miles_ai/the-lost-in-the-middle-problem-why-llms-ignore-the-middle-of-your-context-window-3al2)
on heavy context windows or lack awareness of what's outside the codebase or
the module they currently work on.

**Loop engineering**:
Instead of promping constantly the AI,
design a system that does it for you.

#### (3) AI fundamentals

AI doesn't understand time and memory like humans.
Understanding how LLMs work help you better manage them.

In a nutshell, you need to know about these:
- Weights
- KV cache (and how to optimize it)
- Context Window
- The role of the GPU and how it works
- Skills (reusable prompts basically)
- Cronjobs and automation
- Agents and subagents
- Tools and Harnesses
- Sandboxing

#### (4) Security

Beware of prompt injection.

LLMs with tools can
- have access your internal sensitive data 
- have exposure to the web
- send data

How to protect yourself:

- Sandboxing when ever possible.
- Manually check if sensitive data is accessible such as ssh keys, private tokens, etc.

#### (5) The future

AI is analogous to electricity.

A future without electricity is unthinkable.
But wasting electricity or over-using it is not only harmful to your wallet,
but to the public grid itself.

Use it, don't abuse it.
Stay sharp, read code, do the hard thinking, use it to do the simple yet
fastidious tasks you cannot afford to anymore.

Coding isn't dead. But you do not need to spend that much time on it anymore.

## Spec Driven Developpement

Creating specifications and outcomes that are testable and unambiguous,
and letting AI figuring it out.

This minimizes the prompting, allows AI to auto-control itself and is
usable in multi-agent contexts.

The hard part is not longer writting code, but making AI write it proprely
for you.

The whole point is to focus on the bigger picture, and focus on critical
code only when it matters.

Spec driven dev is not vibe coding.
 
### What's wrong with prompt engineering (vibecoding) ?

To understand that, we must first defince the vibecoding lifecycle.

1. Initial prompt
2. AI starts coding
3. Write a new prompt to request changes
4. AI codes again.

You loop indefinitely step 3 and 4 until
you achieve the desired state, and go back to
step 3 and 4 when you want to update the project.

This is fine for proof of concepts and demos, but this leads
to bad habits and negative consequences:

- You work a lot editing prompts
- You waste tokens
- You bloat the LLM context window
- You do not control the shape of the software proprely
- You skip basic [SDLC](https://en.wikipedia.org/wiki/Systems_development_life_cycle) steps.
- You have lose, ambiguous specifications that leads to technical debt or
bad code implementations.
- You get different results everytime
- You get frustrated, and you pay more for better models

### SDLC in a nutshell

1. Planning and designing
2. loop: implement
3. endloop: testing/QA
4. deployment
5. maintenance

It's important to know conceptually, because it's the basis for Spec Driven
Engineering.

### How SDD works

#### Quick work on GitHub's spec-kit

Before we tackle this, a quick work on [github's spec-kit](https://github.com/github/spec-kit#spec-driven-development).
While this project is not bad, it has some issues.

Because they encourage you to start fast, you may overlook a bunch of stuff.
Second big issue: the `spec.md` is AI generated. If the issue with vibe coding
is misunderstanding and annoying AI prompts iterations, then why is the 
`spec.md` generated by AI ?

This'll become a "trust me bro" project, not a real solution to my AI pain 
points.

My suggestion: Use a proper SRS. Ensure you have detailed specifications.

The goal of SDD is to fix the issues that makes vibecoding innefficient, yet
the specification itself is vibecoded.

1. Requirements

Build a [Software Requirement Specification (SRS)](https://www.geeksforgeeks.org/software-engineering/software-requirement-specification-srs-format/).
This document is not just a prompt, its the source of truth the agentic workflow
you'll setup will work against.

## Data Oriented Design

## OpenJEV as a validator

# About

A mono repo of mono repos. The more context an AI agent has, the better it is at doing its job. Therefore, starting June 5, 2026 I'm gonna try to keep all of my personal coding projects in one repo. This repo is only every intended to be used by me. If there ever comes a point where others need to work on code in here, it will get broken out into it's own open source module/app/repo.

As for allowing others to run any of the code in this repo, that'll be done via artifact packaging scripts.

# Coding conventions

## Branches

Avoid branches if possible. Instead try to make each commit coherent on it's own; a completed spec doc, a working feature, a new executable command

## Commits

Concisely summarize the value add in terms I'll appreciate later. My commits should tell a compelling story of how a large vision of interconnected pieces of software come together in a well executed vision.

## Uncommitted stuff

Don't commit something unless it contributes to the narrative/objectives of SPNC; if the resulting commit message doesn't continue telling the story, don't commit it, maybe put it somewhere else. Or wait for it to actually have some concrete long-term value and then commit it.

## Secrets

Since this repo will NEVER be shared with other people. It is ok to track secrets like admin passwords to equipment, etc. This said, secrets should be clearly marked as such or centralized in a single place in a given project so if the project was published or shared it would be straight forward to rotate the secrets and externalize them.
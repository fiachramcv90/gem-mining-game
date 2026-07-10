---
id: 0002
title: "Godot 4 web export viability on iOS Safari"
type: research
status: open
assignee: fiachramcv (Claude session)
blocked-by: []
---

## Question

Web-first is the chosen platform and all of Fiachra's devices are Apple. Does Godot 4.x's HTML5 export run acceptably on current iOS Safari (threads/SharedArrayBuffer requirements, compatibility renderer vs Forward+, audio quirks, home-screen PWA behaviour, performance)? If not, what are the mitigations (compatibility renderer, single-threaded export) or fallback engines? This is route-critical: a negative answer redraws the platform decision.

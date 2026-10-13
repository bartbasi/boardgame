# Developer accounts: individual or company (PRD Q6b)

- Owner: product-manager
- Checked: 2026-10-13. Facts and sources: docs/api-research.md, APPLE-18 to APPLE-25 and GPLAY-18 to GPLAY-26, blocking risk B12.
- This is product research, not legal or tax advice.

## The choice in one table

| | Apple, individual | Apple, organization | Google Play, personal | Google Play, organization |
|---|---|---|---|---|
| Cost | $99 a year (APPLE-20) | $99 a year (APPLE-20) | $25 once (GPLAY-19) | $25 once (GPLAY-19) |
| What you need | Apple Account with two-factor authentication, your legal name (APPLE-18) | A legal entity (no DBA or trade name), a D-U-N-S Number, authority to sign for it, a working website on its own domain, and an email on that domain (APPLE-19) | Legal name, address, email, phone; possibly a government ID and a credit card; an Android device (GPLAY-19, GPLAY-24) | A D-U-N-S Number, the organization's name, address, phone, and website (GPLAY-20) |
| Name shown as seller | Your personal legal name (APPLE-18) | The company's legal name (APPLE-19) | Your legal name, plus a developer name you choose (GPLAY-21, GPLAY-23) | The company's legal name, plus a developer name you choose (GPLAY-21, GPLAY-23) |
| Address shown publicly | No, for a US-only app (APPLE-24) | No, for a US-only app (APPLE-24) | Country only, because our app has no paid download or in-app purchases (GPLAY-21, GPLAY-22, likely) | Yes, with phone and email (GPLAY-21) |
| Extra step before launch | None | None | Closed test: 12 testers for 14 days in a row, then a production review, usually 7 days or less (GPLAY-24) | Appears exempt (GPLAY-25, likely) |
| Change later | Can move to organization by request, if you founded the company (APPLE-22) | n/a | Can move to organization in Play Console (GPLAY-26) | Cannot move back to personal (GPLAY-26) |

A company's D-U-N-S Number is free and takes up to 5 business days, plus up to 2 more before Apple can see it (APPLE-21). Forming a company has its own cost and paperwork, which this research does not cover.

## What each choice means for us

- **Individual on both stores.** Cheapest and fastest: $99 plus $25, no D-U-N-S Number, and TestFlight and Play internal testing (T-036) can start as soon as the accounts are approved. Your legal name appears as the seller on both stores. Your home address is not shown, as long as the app stays US-only, free, and without in-app purchases. The cost is time on Android: before the first public release, about 12 testers must use a closed test for 14 days, then Google reviews the request (B12). EPN only reviews the app once the listing is live (B4), so this pushes back the first possible commission.
- **Company on both stores.** The company name, not yours, is the seller. Google Play shows the company's address, phone, and email. You need an existing legal entity (an LLC or corporation, not a DBA), a D-U-N-S Number, and a website on the company's domain before you can enroll. The 12-tester closed test appears not to apply. [ASSUMPTION: a company may also separate business and personal liability; ask an accountant or lawyer, this is not legal advice.]

## Recommendation

- If you already own a company with its own website and domain email, enroll it as an organization on both stores now. It skips Google's 12-tester gate, keeps your name off the listings, and avoids a later move.
- If you do not, enroll as an individual on both stores now. Getting the Apple account early unblocks TestFlight in M2 (T-036). Both stores allow moving to a company account later (APPLE-22, GPLAY-26), though Apple's move is a manual request with no published timeline.
- If you go personal on Google Play, plan the closed test early in M5: recruit 12 testers and start it as soon as a stable build exists.
- Whatever you choose, use the same publisher name on both stores, in the privacy policy (T-078), and for BGG (T-087). Tell BGG if it differs from what the application said.

## Not confirmed

- How long Apple's individual to organization move takes, and what it does to existing apps (APPLE-22, APPLE-23).
- How long Apple takes to verify a new enrollment (APPLE-25).
- That EPN affiliate income does not count as monetizing on Google Play, which would make Google show a personal account's full address (GPLAY-22, likely).
- That organization accounts are exempt from Google's 12-tester rule (GPLAY-25, likely), and the exact steps of Google's personal to organization change (GPLAY-26).

# Scalability Roadmap: The Quadrant

This roadmap identifies technical bottlenecks and the strategies required to scale **The Quadrant** from 100 users to 100,000+ users.

## Phase 1: Current State (Early Stage)
- **Database**: Pull-based Firestore queries.
- **Following Feed**: Limited to 30 people (Firestore `whereIn` limit).
- **Search**: Client-side filtering of the last 100 posts.
- **Counters**: Atomic increments on main documents (Likes/Commits).

## Phase 2: Intermediate Store (1k - 10k Users)
- **Search**: Migrate to **Algolia** or **Meilisearch** for full-text search across all posts.
- **Following Feed**: Implement "Slice & Batch" queries to support following up to 500 people.
- **Engagement**: Move from atomic document updates to **Sharded Counters** for high-traffic posts.

## Phase 3: Production Grade (10k+ Users)
- **Fan-out on Write Architecture**: 
  - Instead of querying "who I follow," every new post triggers a Cloud Function.
  - The function copies the Post ID into the "Personal Feed" of every follower.
  - Pro: Feed loading becomes nearly instantaneous for the user.
- **Microservices**: Offload heavy logic (like the Profile Sync engine) to **Firebase Cloud Functions** to save client-side battery and data.
- **Cache Layer**: Implement Redis or Firestore local caching for frequently visited profiles.

---
## Technical Debt to Watch
1. **The 30-Limit Query**: Our current feed logic will break if a user follows more than 30 people. This needs a "Fan-out" fix in Phase 3.
2. **Batch Sync**: As a user gets more posts, updating their name across all of them will take longer. Moving this to the background (Server-side) is critical.

---
*Last Updated: February 2026*

# 006 - Fake Profile Seeder Script

## Summary

Created `backend/scripts/seed_fake_profiles.exs` — a standalone script that seeds ~2000 fake users with profiles and a social graph centered on the primary test user ("me" = +81901111001 / さくら).

## What It Creates

| Entity | Count | Notes |
|--------|-------|-------|
| Users | 2000 | Phone numbers `+81903000001` through `+81903002000` |
| Profiles | 2000 | 30% rich, 40% medium, 30% sparse completeness |
| Friend connections | ~500 | Skewed toward "me" |
| Matchmaker connections | ~80 | "Me" gets 15 matchmakers |

## Social Graph

- 30 direct friends of "me" (10 inner_circle, 20 friends tier)
- 15 matchmakers for "me" (subset of friends, activates matchmaking)
- ~200 friends-of-friends (each of my 30 friends gets 5-10 of their own)
- ~300 background connections among remaining users (hub-and-spoke clusters)
- ~50 matchmaker connections among FoF users

## Key Design Decisions

- **Single Argon2 hash**: Pre-computed once and reused for all 2000 users (avoids hashing 2000x)
- **Pre-generated BSON ObjectIds**: Created before insertion for cross-referencing between users, profiles, and connections
- **Bulk inserts**: `Mongo.insert_many` in batches of 500
- **Idempotent**: Deletes all `+81903*` users, orphaned profiles, and orphaned connections before inserting
- **Tags from DB**: Loads actual tags_catalog at runtime rather than hardcoding
- **user_id as string**: Matches existing seed pattern (`to_string(oid)`)
- **Connection documents**: Match the schema in `Social` — `requester_id`/`recipient_id` as BSON.ObjectId

## Usage

```bash
cd backend && mix run scripts/seed_fake_profiles.exs
```

Requires seeds to be run first (`mix run -e "Koikoi.Seeds.run()"`).

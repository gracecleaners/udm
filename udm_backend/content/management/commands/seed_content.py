"""Seed starter ministry content so a fresh checkout has something to read.

Scripture quotations are King James Version (public domain). Devotional and
article prose here is written for UDM; replace it with curated ministry content
through the admin console rather than editing this command.
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from content.models import (
    Article,
    Devotional,
    DevotionalSeries,
    MediaCollection,
    MediaItem,
    MemoryVerse,
    ResourceStep,
    ResourceTopic,
)

MEMORY_VERSES = [
    ("Romans 12:2", "Be not conformed to this world: but be ye transformed by the renewing of your mind, that ye may prove what is that good, and acceptable, and perfect, will of God."),
    ("Joshua 1:9", "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest."),
    ("Proverbs 3:5-6", "Trust in the LORD with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths."),
    ("Psalm 119:105", "Thy word is a lamp unto my feet, and a light unto my path."),
    ("Isaiah 40:31", "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint."),
    ("John 15:5", "I am the vine, ye are the branches: He that abideth in me, and I in him, the same bringeth forth much fruit: for without me ye can do nothing."),
    ("Matthew 28:19-20", "Go ye therefore, and teach all nations, baptizing them in the name of the Father, and of the Son, and of the Holy Ghost: Teaching them to observe all things whatsoever I have commanded you: and, lo, I am with you alway, even unto the end of the world."),
    ("Philippians 4:6-7", "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God."),
    ("1 Peter 5:6-7", "Humble yourselves therefore under the mighty hand of God, that he may exalt you in due time: Casting all your care upon him; for he careth for you."),
    ("2 Timothy 2:2", "And the things that thou hast heard of me among many witnesses, the same commit thou to faithful men, who shall be able to teach others also."),
]

DEVOTIONALS = [
    {
        "title": "A Heart That Listens",
        "scripture_reference": "1 Samuel 3:1-10",
        "author": "UDM Ministry Team",
        "excerpt": "Samuel did not recognise God's voice at first, but he had the right posture: he was where he could be called.",
        "body": (
            "Eli was half asleep in his own quarters while Samuel lay in the temple. The word of the Lord was "
            "rare in those days, and the boy had no framework for what was happening. So when the call came, he "
            "answered the only way he knew how: he ran to the man who seemed to be in charge.\n\n"
            "What Eli gave Samuel was not an experience, only a sentence: go lie down, and if He calls again, say "
            "'Speak, Lord, for your servant hears.' Listening is often taught to us by people who model it rather "
            "than explain it. Samuel's breakthrough was ordinary obedience repeated until it became a reflex.\n\n"
            "On a campus full of competing voices, the discipline is not first to say something impressive. It is "
            "to stay within earshot and answer honestly when Scripture reads you rather than the other way around."
        ),
        "reflection_questions": [
            "What makes God's voice hard to distinguish in your week?",
            "Who in your life has modelled Scripture-saturated listening?",
            "What would change if you said 'Speak, Lord' before opening your notes?",
        ],
        "application": "Read 1 Samuel 3 slowly once, then re-read verses 9-10. Write the one sentence you would say to God if He asked what you need today.",
        "prayer": "Lord, quiet the noise long enough for me to know I am being addressed. Speak; your servant is listening.",
        "memory_scripture_reference": "1 Samuel 3:9",
        "reading_minutes": 5,
    },
    {
        "title": "Rooted and Repeating",
        "scripture_reference": "John 15:1-8",
        "author": "UDM Ministry Team",
        "excerpt": "Fruitfulness in Jesus' picture is a consequence of connection, not of effort alone.",
        "body": (
            "Jesus does not describe a productivity system. He describes a plant. A branch does not strain to "
            "produce grapes; it stays attached and the sap does the work. The verse that unsettles most students "
            "is 'without me ye can do nothing' - not 'without me you do less'.\n\n"
            "That reframes spiritual disciplines. Prayer, Scripture, confession, and fellowship are not payments "
            "that purchase growth; they are the point of contact where a branch remains in the vine. Repetition is "
            "not the enemy of vitality but its mechanism, the same way breathing is not boring to the body that "
            "needs it.\n\n"
            "The pruning verse is spoken to a university audience that understands pressure: deadlines, "
            "expectations, loss. Jesus calls the Father's work in it purposeful rather than punitive, and the "
            "outcome 'the full ripeness of a branch that never left the vine'."
        ),
        "reflection_questions": [
            "Which discipline has become effort without connection?",
            "Where has pressure produced fruit you did not expect?",
            "What would a realistic daily abiding rhythm look like this semester?",
        ],
        "application": "Choose one fixed daily time for fifteen minutes this week. Keep it deliberately small so it survives exam week.",
        "prayer": "Jesus, keep me attached. Teach me to value the rhythm more than the measurement of the rhythm.",
        "memory_scripture_reference": "John 15:5",
        "reading_minutes": 6,
    },
    {
        "title": "Sent on Campus",
        "scripture_reference": "Matthew 28:16-20",
        "author": "UDM Ministry Team",
        "excerpt": "The commission was given to students in a classroom, not to professionals in a building.",
        "body": (
            "The eleven went back to a hill in Galilee, and the sentence they received has a strange grammar: all "
            "authority, therefore go. The 'therefore' rests on Jesus' authority rather than on their competence, "
            "which is fortunate because they had recently failed him in a much less public way.\n\n"
            "Making disciples is a curriculum, not a conversion technique: going, inviting, teaching obedience, and "
            "staying. Obedience is the content because Jesus taught things he had commanded, not things he had "
            "merely explained.\n\n"
            "For a discipleship movement on university campuses, this means our first aim is not a large event but "
            "a reproducible rhythm one student can carry into a second student's life within a semester."
        ),
        "reflection_questions": [
            "Who could you teach obedience to, not just information about?",
            "What is the mildest form of 'going' available in your faculty this month?",
            "Where are you waiting for competence that the text assigns to Christ?",
        ],
        "application": "List three classmates who are not yet in any group. Pray for one by name today and arrange a coffee this week.",
        "prayer": "Lord Jesus, you hold the authority; I hold the assignment. Send me to the next person.",
        "memory_scripture_reference": "Matthew 28:19",
        "reading_minutes": 5,
    },
]

ARTICLES = [
    {
        "title": "How to Study a Chapter in Twenty Minutes",
        "category": "Bible study",
        "author": "UDM Ministry Team",
        "excerpt": "A repeatable method for a student who has a chapter, a pen, and very little time.",
        "body": (
            "Most students skip Bible study not for lack of desire but because every attempt feels unstructured. A "
            "method only needs to survive one reading to be useful.\n\n"
            "Start by reading the whole chapter without stopping. Write one sentence describing what the chapter "
            "says, and resist the temptation to make it sound spiritual. Then read again slowly and mark three "
            "things: a word that repeats, a command, and a surprise. The surprise matters most because it is where "
            "your first reading was wrong.\n\n"
            "Third pass, ask one question of the text and answer only from the text. Cross-references come last; "
            "they are useful for checking an observation, not for escaping one. Close by writing one sentence about "
            "what the author says God is like here, and one action you will take before tomorrow.\n\n"
            "Twenty minutes is enough for this. A group of six students doing it badly together for a semester "
            "beats one devoted scholar doing it perfectly alone."
        ),
        "reading_minutes": 4,
    },
    {
        "title": "Friendship That Carries Doubt Well",
        "category": "Christian relationships",
        "author": "UDM Ministry Team",
        "excerpt": "Why honest Christian friendship survives questions that a devotional feed cannot.",
        "body": (
            "University is when many students first hear their faith challenged by someone who has actually read "
            "the arguments. The predictable response is either performance or silence, and both are symptoms of "
            " friendships that were built to share victories rather than questions.\n\n"
            "James 5:16 pairs confession with healing, which suggests that the safe place and the medicine are the "
            "same room. Practically, this is built by small honesty repeated: telling a friend what you are "
            "actually struggling with this week, and letting them answer without your managing their reaction.\n\n"
            "Doubt that is spoken stays bounded. Doubt that is silenced keeps working underground, usually surfacing "
            "as withdrawal from the very group that could have helped. A discipleship community is not a place where "
            "everyone has answers; it is a place where questions are handled with Scripture, patience, and follow-up."
        ),
        "reading_minutes": 4,
    },
]


RESOURCE_TOPICS = [
    {
        "title": "Receive Christ",
        "summary": "Five short steps that walk through what the Bible says about becoming a follower of Jesus, ending with a prayer you can pray yourself.",
        "order": 1,
        "steps": [
            {
                "order": 1,
                "title": "God is near, and He knows you",
                "scripture_reference": "Acts 17:27-28",
                "excerpt": "Before any request is made of you, the text says a God who is not far from anyone.",
                "body": (
                    "\"That they should seek the Lord, if haply they might feel after him, and find him, though he "
                    "be not far from every one of us: For in him we live, and move, and have our being.\" — Acts 17:27-28\n\n"
                    "Paul spoke that sentence in a city full of temples, and he said something strange for a "
                    "religious place: this God does not live in buildings, and He is not at a distance waiting for "
                    "you to earn an audience. He is the ground you are standing on.\n\n"
                    "People often arrive at faith thinking they must first clean something up. The order in the text "
                    "is the other way around: He is already near, and you are invited to turn and notice."
                ),
                "reading_minutes": 2,
            },
            {
                "order": 2,
                "title": "We have all turned aside",
                "scripture_reference": "Romans 3:23",
                "excerpt": "The bad news is honest before it is painful: none of us has lived the life we know we should.",
                "body": (
                    "\"For all have sinned, and come short of the glory of God.\" — Romans 3:23\n\n"
                    "\"All\" includes the person who raised you, the lecturer you respect, and you. Sin in Scripture "
                    "is not only doing wrong things; it is the deeper fact that we have each, at some point, "
                    "preferred our own direction to God's, and that we cannot fix the record by deciding to try "
                    "harder next term.\n\n"
                    "This step is the one people skip because it feels condemning. Read it again as a diagnosis: a "
                    "doctor who names an illness accurately is not insulting you, he is making a treatment possible."
                ),
                "reading_minutes": 2,
            },
            {
                "order": 3,
                "title": "Love reached across",
                "scripture_reference": "Romans 5:8",
                "excerpt": "God did not wait for us to be worth it.",
                "body": (
                    "\"But God commendeth his love toward us, in that, while we were yet sinners, Christ died for "
                    "us.\" — Romans 5:8\n\n"
                    "\"While we were yet sinners\" is the phrase that makes Christianity different from a "
                    "self-improvement plan. The cross is not the reward for people who had sorted themselves out; it "
                    "is the move God made while they were still hostile to Him.\n\n"
                    "\"For God so loved the world, that he gave his only begotten Son, that whosoever believeth in "
                    "him should not perish, but have everlasting life.\" — John 3:16. Both verses are about a gift "
                    "offered before you were in a state to deserve one."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 4,
                "title": "Grace means you cannot earn it",
                "scripture_reference": "Ephesians 2:8-9",
                "excerpt": "Salvation is received, not paid for — which is a relief and also a reorientation.",
                "body": (
                    "\"For by grace are ye saved through faith; and that not of yourselves: it is the gift of God: "
                    "Not of works, lest any man should boast.\" — Ephesians 2:8-9\n\n"
                    "If being right with God could be produced by good behaviour, the final word would belong to the "
                    "best-behaved person. Scripture hands that word to God instead. Faith is not a work that "
                    "purchases the gift either; it is the open hand that takes it.\n\n"
                    "This is why nothing in the next step is a test. There is no minimum of understanding, no required "
                    "number of hours, no interview. There is only the question of whether you will receive what was "
                    "already paid for."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 5,
                "title": "Calling on Him",
                "scripture_reference": "Romans 10:9-13",
                "excerpt": "What it actually looks like to trust Jesus — including a prayer you can say out loud.",
                "body": (
                    "\"That if thou shalt confess with thy mouth the Lord Jesus, and shalt believe in thine heart "
                    "that God hath raised him from the dead, thou shalt be saved. … For whosoever shall call upon "
                    "the name of the Lord shall be saved.\" — Romans 10:9-13\n\n"
                    "Believing in the heart and confessing with the mouth are the same act described from the "
                    "inside and the outside. You are not reciting a formula that works by its syllables; you are "
                    "agreeing with God about your need, about Christ's death and resurrection, and about who is now "
                    "in charge of your life.\n\n"
                    "\"Behold, I stand at the door, and knock: if any man hear my voice, and open the door, I will "
                    "come in to him, and will sup with him, and he with me.\" — Revelation 3:20. If you want to "
                    "pray, these words are a starting point, not a magic formula: Lord Jesus, I admit that I have "
                    "lived my own way and that I need you. I believe you died for me and rose again. Thank you for "
                    "forgiving me. I turn from my old direction and trust you now as my Lord and Saviour. Live in "
                    "me, and teach me what life with you looks like. Amen.\n\n"
                    "If you meant that prayer, the next guide — New Believer — is where to go from here."
                ),
                "reading_minutes": 4,
            },
        ],
    },
    {
        "title": "New Believer",
        "summary": "An introduction to the Christian life for someone who has just trusted Christ: assurance, Scripture, prayer, church and what to expect under pressure.",
        "order": 2,
        "steps": [
            {
                "order": 1,
                "title": "You can know that you are saved",
                "scripture_reference": "1 John 5:13",
                "excerpt": "Assurance is not bragging; John wrote a chapter of the Bible so that new believers could stop guessing.",
                "body": (
                    "\"These things have I written unto you that believe on the name of the Son of God; that ye may "
                    "know that ye have eternal life.\" — 1 John 5:13\n\n"
                    "\"Therefore if any man be in Christ, he is a new creature: old things are passed away; behold, "
                    "all things are become new.\" — 2 Corinthians 5:17. The new creation is a fact about your "
                    "standing before God before it is a description of your feelings.\n\n"
                    "Expect the feelings to lag. A newborn's reflexes are not trained yet, and its parents do not "
                    "love it on the basis of its performance. If you are waiting for a sensation before you believe "
                    "what God says, you have turned assurance into another work to earn."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 2,
                "title": "Learning to hear God through the Bible",
                "scripture_reference": "2 Timothy 3:16-17",
                "excerpt": "Scripture is how a new believer learns the language God already speaks.",
                "body": (
                    "\"All scripture is given by inspiration of God, and is profitable for doctrine, for reproof, "
                    "for correction, for instruction in righteousness: That the man of God may be perfect, throughly "
                    "furnished unto all good works.\" — 2 Timothy 3:16-17\n\n"
                    "Start in one of the Gospels — Mark is short, John is deep — and read a few verses rather than a "
                    "quota. Ask one question each time: what does this passage tell me about God, and what does it "
                    "ask of me? Write the answers in the margin or in a notes app; an unread Bible tends to feel "
                    "silent because we never write down what we actually heard.\n\n"
                    "\"Thy word is a lamp unto my feet, and a light unto my path.\" — Psalm 119:105. A lamp lights "
                    "the next step, not the whole journey. Do not conclude that God is unclear because you cannot "
                    "see five years from here."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 3,
                "title": "Talking to God, in the ordinary",
                "scripture_reference": "Philippians 4:6",
                "excerpt": "Prayer is not a performance for God's benefit; it is the daily conversation of a child with a Father.",
                "body": (
                    "\"Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let "
                    "your requests be made known unto God.\" — Philippians 4:6\n\n"
                    "\"Draw nigh to God, and he will draw nigh to you.\" — James 4:8. Two habits carry a new "
                    "believer: say what you actually mean rather than what sounds spiritual, and connect prayer to "
                    "reading, so that you answer God with the same text you just heard Him from.\n\n"
                    "You will have days when prayer feels like talking into a ceiling. Pray anyway, and keep the "
                    "sentences short. Consistency teaches more than eloquence, and the Spirit helps the prayers we "
                    "cannot yet organise."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 4,
                "title": "Finding people you can grow old in",
                "scripture_reference": "Acts 2:42",
                "excerpt": "Faith is not a private subscription. The first Christians stayed together, and so must you.",
                "body": (
                    "\"And they continued steadfastly in the apostles' doctrine and fellowship, and in breaking of "
                    "bread, and in prayers.\" — Acts 2:42\n\n"
                    "\"And let us consider one another to provoke unto love and to good works: Not forsaking the "
                    "assembling of ourselves together, as the manner of some is; but exhorting one another: and so "
                    "much the more, as ye see the day approaching.\" — Hebrews 10:24-25. Doctrine, fellowship, "
                    "shared meals and prayer — four ordinary things, and that is exactly what most new believers "
                    "underestimate.\n\n"
                    "Look for a church that teaches the Bible plainly and a campus fellowship that expects you to "
                    "serve, not just attend. You will disappoint them and they will disappoint you; a community that "
                    "can survive that is a community worth staying in."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 5,
                "title": "When faith is tested",
                "scripture_reference": "James 1:2-5",
                "excerpt": "Pressure after conversion is normal, not evidence that you have lost something.",
                "body": (
                    "\"My brethren, count it all joy when ye fall into divers temptations; Knowing this, that the "
                    "trying of your faith worketh patience.\" — James 1:2-3\n\n"
                    "New believers usually meet three things: opposition from friends, dryness in their own "
                    "devotions, and questions they cannot answer. None of these means the conversion was fake. "
                    "Jesus described a seed that springs up quickly and withers under heat — shallow soil is a "
                    "warning about depth, not about whether the plant is alive.\n\n"
                    "\"If any of you lack wisdom, let him ask of God, that giveth to all men liberally, and upbraideth "
                    "not; and it shall be given him.\" — James 1:5. Ask honestly, in the questions you actually "
                    "have, and ask through people you trust rather than only in your own head."
                ),
                "reading_minutes": 3,
            },
        ],
    },
    {
        "title": "Who God Is",
        "summary": "Three readings on the character of God: light, love, and holiness that is still approachable.",
        "order": 3,
        "steps": [
            {
                "order": 1,
                "title": "God is light",
                "scripture_reference": "1 John 1:5",
                "excerpt": "There is no hidden motive in God.",
                "body": (
                    "\"This is the message which we have heard of him, and declare unto you, that God is light, and "
                    "in him is no darkness at all.\" — 1 John 1:5\n\n"
                    "Light does two things: it reveals, and it is honest about what it reveals. When someone says "
                    "God is love but never says God is light, they end up with a god who approves whatever they are "
                    "already doing.\n\n"
                    "The comfort in the sentence is in the second half. Everything false in you is already visible "
                    "to God, and He is still not done with you — which is why the next verse invites confession "
                    "rather than escape."
                ),
                "reading_minutes": 2,
            },
            {
                "order": 2,
                "title": "God is love",
                "scripture_reference": "1 John 4:8",
                "excerpt": "Love is not something God does when He feels like it; it is what He is.",
                "body": (
                    "\"He that loveth not knoweth not God; for God is love.\" — 1 John 4:8\n\n"
                    "John's sentence is about God's nature, not about human feelings. The proof in the chapter is a "
                    "historical claim — that God sent His Son — which means divine love costs the one who gives it.\n\n"
                    "This matters most on the days when God seems distant. A love that depends on your mood is not "
                    "love; a love that acted first and is described as God's own being is a ground you can stand on "
                    "when your feelings cannot."
                ),
                "reading_minutes": 2,
            },
            {
                "order": 3,
                "title": "Holy and still reachable",
                "scripture_reference": "Isaiah 6:3; Hebrews 4:16",
                "excerpt": "The God too holy to approach would be a different problem from the God too near to respect.",
                "body": (
                    "\"Holy, holy, holy, is the LORD of hosts: the whole earth is full of his glory.\" — Isaiah 6:3\n\n"
                    "Isaiah's reaction to holiness was \"Woe is me\", and the text does not scold him for it. "
                    "Holiness is the seriousness at the centre of the universe. But the same Bible then invites: "
                    "\"Let us therefore come boldly unto the throne of grace, that we may obtain mercy, and find "
                    "grace to help in time of need.\" — Hebrews 4:16\n\n"
                    "Both halves belong together. Holiness without access produces fear; access without holiness "
                    "produces indifference. Christianity is the rare claim that the two are true at once, because "
                    "the throne is now a throne of grace."
                ),
                "reading_minutes": 3,
            },
        ],
    },
    {
        "title": "Prayer",
        "summary": "What prayer is, the pattern Jesus gave, and what to do on the days it feels impossible.",
        "order": 4,
        "steps": [
            {
                "order": 1,
                "title": "Being heard, not impressing",
                "scripture_reference": "Matthew 6:6",
                "excerpt": "Jesus assumed his listeners would rather be heard by God than admired by people.",
                "body": (
                    "\"But when thou prayest, enter into thy closet, and when thou hast shut thy door, pray to thy "
                    "Father which is in secret; and thy Father which seeth in secret shall reward thee openly.\" — "
                    "Matthew 6:6\n\n"
                    "Jesus' warning in this passage is about an audience. The instinct to pray for the effect it has "
                    "on others — including on yourself — is why long public prayers are so rarely long private ones.\n\n"
                    "\"And ye shall seek me, and find me, when ye shall search for me with all your heart.\" — "
                    "Jeremiah 29:13. The search that finds is honest rather than impressive. Say what you actually "
                    "think about the last week of your life."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 2,
                "title": "The pattern Jesus gave",
                "scripture_reference": "Matthew 6:9-10",
                "excerpt": "The Lord's Prayer is a shape to pray inside, not a formula to repeat mechanically.",
                "body": (
                    "\"Our Father which art in heaven, Hallowed be thy name. Thy kingdom come. Thy will be done in "
                    "earth, as it is in heaven.\" — Matthew 6:9-10\n\n"
                    "Notice the order: address, worship, then the requests. The prayer begins by naming who God is "
                    "before listing what is needed, which rearranges the list by itself. It is also communal — our "
                    "Father, not my Father — so no one prays it entirely for themselves.\n\n"
                    "A workable habit is to take one clause slowly and stay with it until you have something real "
                    "to say about it, then move on. Six sentences prayed honestly beat a whole chapter recited."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 3,
                "title": "When you cannot put it into words",
                "scripture_reference": "Romans 8:26",
                "excerpt": "The Spirit helps with the prayers you cannot organise.",
                "body": (
                    "\"Likewise the Spirit also helpeth our infirmities: for we know not what we should pray for as "
                    "we ought: but the Spirit itself maketh intercession for us with groanings which cannot be "
                    "uttered.\" — Romans 8:26\n\n"
                    "Paul assumes confusion, not as a failure of spirituality but as a normal part of being a "
                    "creature who cannot see the whole picture. The verse does not say the groaning is eloquent; it "
                    "says it is carried.\n\n"
                    "On those days: one sentence, repeated, is a prayer. \"Lord, I do not know what to ask for. You "
                    "do.\" — and then stay where you are."
                ),
                "reading_minutes": 3,
            },
        ],
    },
    {
        "title": "The Bible",
        "summary": "Where these books came from, how to read one for yourself, and what to do with a passage you cannot resolve.",
        "order": 5,
        "steps": [
            {
                "order": 1,
                "title": "Where these books came from",
                "scripture_reference": "2 Peter 1:21",
                "excerpt": "The Bible's origin story is people speaking, not dictation to robots.",
                "body": (
                    "\"For the prophecy came not in old time by the will of man: but holy men of God spake as they "
                    "were moved by the Holy Ghost.\" — 2 Peter 1:21\n\n"
                    "Both halves matter. The authors wrote with their own vocabulary, style and situation — which is "
                    "why four Gospel accounts differ in their details — and the text is still reliably God's witness "
                    "about Himself.\n\n"
                    "\"All scripture is given by inspiration of God, and is profitable for doctrine, for reproof, for "
                    "correction, for instruction in righteousness.\" — 2 Timothy 3:16. Its usefulness is the test "
                    "worth trying: read it long enough to be corrected by it."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 2,
                "title": "How to read it for yourself",
                "scripture_reference": "Acts 17:11",
                "excerpt": "The Bereans were called noble because they checked, not because they agreed.",
                "body": (
                    "\"These were more noble than those in Thessalonica, in that they received the word with all "
                    "readiness of mind, searching the scriptures daily, whether those things were so.\" — Acts 17:11\n\n"
                    "Readiness and checking are held together in one sentence. A believer who never checks is "
                    "gullible; a checker who never receives anything is only exercising suspicion. Both halves are "
                    "commendations here.\n\n"
                    "Daily is the operative word: a small amount read honestly each day teaches more than one "
                    "heroic session per term. Start in a Gospel, read a paragraph, write one observation and one "
                    "question, and keep going tomorrow."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 3,
                "title": "What to do with a hard passage",
                "scripture_reference": "Deuteronomy 29:29",
                "excerpt": "Not everything is yours to settle today, and that is stated as mercy rather than a rebuke.",
                "body": (
                    "\"The secret things belong unto the LORD our God: but those things which are revealed belong "
                    "unto us and to our children for ever, that we may do all the words of this law.\" — "
                    "Deuteronomy 29:29\n\n"
                    "The purpose clause is practical: the revealed things exist so that we may obey. A hard "
                    "passage that you cannot resolve is not a threat to faith if the clear text next to it is "
                    "something you can actually do.\n\n"
                    "So: ask a mature believer or a minister, write the question down instead of chewing on it, and "
                    "obey what is already obvious. Questions you keep get answered more often than questions you "
                    "speak about loudly."
                ),
                "reading_minutes": 3,
            },
        ],
    },
    {
        "title": "The Gospel",
        "summary": "The news itself: what the Bible reports about Christ's death, burial and resurrection, and why it is good news now.",
        "order": 6,
        "steps": [
            {
                "order": 1,
                "title": "News before advice",
                "scripture_reference": "1 Corinthians 15:3-4",
                "excerpt": "Paul's summary of the gospel reads like a report of events, not a list of instructions.",
                "body": (
                    "\"For I delivered unto you first of all that which I also received, how that Christ died for "
                    "our sins according to the scriptures; And that he was buried, and that he rose again the third "
                    "day according to the scriptures.\" — 1 Corinthians 15:3-4\n\n"
                    "Three verbs, each one a claim about something that happened: died, buried, rose. A burial is "
                    "included because it establishes that He really died; a rising on the third day is included "
                    "because death was the point at issue.\n\n"
                    "\"For our sins\" is the part that makes it good news rather than merely interesting history."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 2,
                "title": "The cross",
                "scripture_reference": "Galatians 2:20",
                "excerpt": "The cross is personal before it is a theory.",
                "body": (
                    "\"I am crucified with Christ: nevertheless I live; yet not I, but Christ liveth in me: and the "
                    "life which I now live in the flesh I live by the faith of the Son of God, who loved me, and "
                    "gave himself for me.\" — Galatians 2:20\n\n"
                    "Paul argues the cross backward from its effect: an old direction ended, and the present life is "
                    "now lived by trusting a Person who acted on his behalf. \"Who loved me\" is singular — this is "
                    "not only a cosmic transaction but a personal one.\n\n"
                    "Atonement theories try to explain how the cross works. The first question is simpler: do you "
                    "accept that it was for you?"
                ),
                "reading_minutes": 3,
            },
            {
                "order": 3,
                "title": "The empty tomb changes the tense",
                "scripture_reference": "Matthew 28:5-6",
                "excerpt": "The angel's sentence is written for people who are still looking for a dead man.",
                "body": (
                    "\"And the angel answered and said unto the women, Fear not ye: for I know that ye seek Jesus, "
                    "which was crucified. He is not here: for he is risen, as he said. Come, see the place where the "
                    "Lord lay.\" — Matthew 28:5-6\n\n"
                    "\"As he said\" is the important clause: the resurrection settles Jesus' own claims. A teacher "
                    "who rises from the dead has authority over the things He taught, including the hard ones.\n\n"
                    "It also means Christian faith is addressed to a living person. Prayer, obedience and "
                    "discipleship are all in the present tense for the same reason — the tomb being empty is not a "
                    "closing note but the reason the conversation continues."
                ),
                "reading_minutes": 3,
            },
        ],
    },
    {
        "title": "Church",
        "summary": "What the Bible calls the church, why gathering is not optional, and where a campus fellowship fits.",
        "order": 7,
        "steps": [
            {
                "order": 1,
                "title": "Not a building",
                "scripture_reference": "1 Peter 2:9",
                "excerpt": "The New Testament word for church means a gathered people, and the building is named after them.",
                "body": (
                    "\"But ye are a chosen generation, a royal priesthood, an holy nation, a peculiar people; that "
                    "ye should shew forth the praises of him who hath called you out of darkness into his marvellous "
                    "light.\" — 1 Peter 2:9\n\n"
                    "Paul calls believers \"the body of Christ\" (1 Corinthians 12:27), and the image is deliberate: "
                    "a body is an organism with functions, not a club with meetings. You do not belong to a church "
                    "the way you belong to a gym you pay to use.\n\n"
                    "That is why attendance language misses the point. The question Scripture asks is what you are "
                    "doing with other believers, not whether your name is on a list."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 2,
                "title": "Why gathering is not optional",
                "scripture_reference": "Hebrews 10:24-25",
                "excerpt": "Consider one another — the command assumes you are actually in each other's way.",
                "body": (
                    "\"And let us consider one another to provoke unto love and to good works: Not forsaking the "
                    "assembling of ourselves together, as the manner of some is; but exhorting one another: and so "
                    "much the more, as ye see the day approaching.\" — Hebrews 10:24-25\n\n"
                    "The verse gives the reason for gathering before the warning against abandoning it: provoking "
                    "to love and good works. It is not a schedule of services but a mechanism of mutual sharpening.\n\n"
                    "\"As the manner of some is\" is an honest observation, not a scolding — drifting happens "
                    "gradually and to respectable people. If you have drifted, do not try to land a whole semester "
                    "of absence in one week; come on a Sunday, then stay afterwards for a conversation."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 3,
                "title": "Campus fellowship and local church",
                "scripture_reference": "1 Corinthians 12:27",
                "excerpt": "They are not rivals; one is where you are sent, the other is where you are rooted.",
                "body": (
                    "\"Now ye are the body of Christ, and members in particular.\" — 1 Corinthians 12:27\n\n"
                    "A campus fellowship does things a local church does badly: it is present where students "
                    "actually are, and it reaches classmates during term. A local church does things a fellowship "
                    "cannot: it ordains, catechises, celebrates communion across generations, and stays with you "
                    "when you graduate and move.\n\n"
                    "The healthy pattern is both, with the church as the root. If your fellowship is treated as a "
                    "substitute for belonging somewhere on a Sunday, something will be missing in a few years — and "
                    "if your church has no contact with your campus at all, most of your week is unblessed by design."
                ),
                "reading_minutes": 3,
            },
        ],
    },
    {
        "title": "Faith",
        "summary": "What faith is, where it comes from, and how it differs from believing hard about nothing.",
        "order": 8,
        "steps": [
            {
                "order": 1,
                "title": "What faith is",
                "scripture_reference": "Hebrews 11:1",
                "excerpt": "Faith is a way of holding what God has said, not a substitute for evidence.",
                "body": (
                    "\"Now faith is the substance of things hoped for, the evidence of things not seen.\" — "
                    "Hebrews 11:1\n\n"
                    "The chapter then lists people who acted on a promise — Abraham leaving, Moses refusing, judges "
                    "holding out. Faith is never described in this book as a mood or as a positive expectation; it is "
                    "a stance toward a Person who has spoken.\n\n"
                    "\"Things not seen\" does not mean things imagined. The object of Christian faith is God's own "
                    "character and Christ's finished work, both of which the New Testament grounds in historical "
                    "claims."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 2,
                "title": "Where faith comes from",
                "scripture_reference": "Romans 10:17",
                "excerpt": "Faith is produced by hearing, which is why a Christian reads and sits under teaching.",
                "body": (
                    "\"So then faith cometh by hearing, and hearing by the word of God.\" — Romans 10:17\n\n"
                    "Paul is describing a cause. Faith does not arrive by straining harder; it grows where God's "
                    "word is being spoken and heard, which is why drift usually begins with silence rather than with "
                    "a doubt.\n\n"
                    "This has practical consequences: keep reading Scripture, keep hearing it explained by someone "
                    "who has prepared, keep talking with believers whose faith you have watched survive something. "
                    "Those are the ordinary channels the verse names."
                ),
                "reading_minutes": 3,
            },
            {
                "order": 3,
                "title": "Faith that is not alone",
                "scripture_reference": "James 2:17",
                "excerpt": "Works do not create saving faith; they prove that it was there.",
                "body": (
                    "\"Even so faith, if it hath not works, is dead, being alone.\" — James 2:17\n\n"
                    "James and Paul are not contradictory: Paul argues that a person is justified by faith rather "
                    "than by works of the law, and James argues that a faith which never produces anything was "
                    "never faith. The same verb appears in both — true faith is the kind that moves.\n\n"
                    "\"And if ye have faith as a grain of mustard seed… nothing shall be impossible unto you.\" — "
                    "Matthew 17:20 puts the emphasis on the object and the direction rather than the size. A small, "
                    "genuine trust that actually obeys today is not a defective version of a large one; it is the "
                    "same species."
                ),
                "reading_minutes": 3,
            },
        ],
    },
]

# The Learn tab. No YouTube links are invented here: staff paste each
# recording's address in the console, and until they do the app shows the
# teaching's description and offers no play control at all. Shelf artwork is
# uploaded in the console too, so a fresh checkout gets plain tiles.
MEDIA_SHELVES = [
    {
        "title": "SOMA",
        "description": "Study, Observe, Meditate, and Apply the Scriptures. Short teaching recordings that take one passage all the way through.",
        "order": 1,
        "items": [
            {
                "order": 1,
                "title": "True faith sides with God | Hebrews 11:29-31",
                "excerpt": "The verse lists people who did nothing heroic until the moment asked for everything.",
                "body": (
                    "\"By faith the people passed through the Red sea as by dry land…\" — Hebrews 11:29\n\n"
                    "Hebrews 11 is not a gallery of successful people; it is a list of people who were asked to "
                    "act before they could see the outcome. The passage puts Rahab next to Israelite spies, which "
                    "is the point: faith is not about a person's record but about who they trusted.\n\n"
                    "Observe what the text says the faith did and did not do. It did not explain the situation. It "
                    "sided with God's people when that was the unsafe choice.\n\n"
                    "Meditate on one decision this week where the faithful option is visible but uncomfortable, "
                    "and apply it before the feeling arrives."
                ),
                "duration_seconds": 940,
            },
            {
                "order": 2,
                "title": "Listening when God seems quiet | 1 Kings 19:9-13",
                "excerpt": "Elijah expected a wind and an earthquake. The text says the Lord was in neither.",
                "body": (
                    "\"And after the earthquake a fire; but the LORD was not in the fire: and after the fire a "
                    "still small voice.\" — 1 Kings 19:12\n\n"
                    "Elijah had just won the public contest on Carmel and then run for his life in a single news "
                    "cycle. What God gives him is not a lecture about his faith but bread, sleep, and a sentence.\n\n"
                    "The teaching walks through why the quiet moment is harder to recognise than the dramatic one, "
                    "and what it means to be \"in the cave\" — the place of hiding — and addressed there anyway.\n\n"
                    "Apply it by lowering the volume for one day and writing down what you actually heard."
                ),
                "duration_seconds": 1135,
            },
        ],
    },
    {
        "title": "Uliza",
        "description": "Ask a question, get a biblical response. Recorded answers to the questions students actually bring.",
        "order": 2,
        "items": [
            {
                "order": 1,
                "title": "Does God care about my grades? | Proverbs 3:5-6",
                "excerpt": "The honest answer refuses the split between spiritual life and academic life.",
                "body": (
                    "\"Trust in the LORD with all thine heart; and lean not unto thine own understanding. In all "
                    "thy ways acknowledge him, and he shall direct thy paths.\" — Proverbs 3:5-6\n\n"
                    "\"In all thy ways\" includes the library. The question usually hides an assumption that God is "
                    "interested in the devotional part of the day and not the part with a deadline.\n\n"
                    "This answer looks at what acknowledging God in study actually looks like: honest work, "
                    "refusing to cheat when it costs a mark, and not treating an exam as the final word about your "
                    "worth."
                ),
                "duration_seconds": 610,
            },
        ],
    },
    {
        "title": "Podcast",
        "description": "Longer conversations going in depth about our blogs and other ministry teaching.",
        "order": 3,
        "items": [
            {
                "order": 1,
                "title": "What a campus fellowship is for | Acts 2:42-47",
                "excerpt": "A conversation about the four devotions in the earliest assembly and which ones we have quietly dropped.",
                "body": (
                    "\"And they continued steadfastly in the apostles' doctrine and fellowship, and in breaking of "
                    "bread, and in prayers.\" — Acts 2:42\n\n"
                    "Four practices, one sentence. The conversation works through them in order and asks which of "
                    "the four a modern campus group is best at and which it is happiest to skip.\n\n"
                    "\"And the Lord added to the church daily such as should be saved\" is the last clause, and the "
                    "recording spends its closing minutes there: growth is described as something that happened to "
                    "the assembly, not something it organised."
                ),
                "duration_seconds": 2580,
            },
        ],
    },
]


class Command(BaseCommand):
    help = "Create starter memory verses, a devotion series, articles, resource guides and Learn shelves (idempotent)."

    def add_arguments(self, parser):
        parser.add_argument("--flush-existing", action="store_true", help="Publish-stop the current memory verses first.")

    @transaction.atomic
    def handle(self, *args, **options):
        if options["flush_existing"]:
            MemoryVerse.objects.update(is_published=False)

        for reference, text in MEMORY_VERSES:
            MemoryVerse.objects.get_or_create(
                reference=reference,
                translation_code="kjv",
                defaults={
                    "text": text,
                    "attribution": "King James Version (public domain)",
                    "is_published": True,
                },
            )

        # Starter content arrives as one series so the Devotions grid has
        # something to open; the ministry renames it and adds its own in the
        # console. No cover URL is invented here — a series without art gets
        # the app's own monogram tile.
        series, _ = DevotionalSeries.objects.get_or_create(
            title="Foundations for Campus Life",
            defaults={
                "description": "Three readings on hearing God, staying in Christ and being sent.",
                "order": 1,
                "is_published": True,
            },
        )

        for order, item in enumerate(DEVOTIONALS, start=1):
            Devotional.objects.update_or_create(
                title=item["title"],
                defaults={**item, "series": series, "day": order, "is_published": True},
            )

        for item in ARTICLES:
            Article.objects.update_or_create(
                title=item["title"],
                defaults={**item, "is_published": True},
            )

        # The home "Find resources on" list. No video URLs are invented here: a
        # step with no `video_url` simply renders no video action in the app.
        step_total = 0
        for guide in RESOURCE_TOPICS:
            topic, _ = ResourceTopic.objects.update_or_create(
                title=guide["title"],
                defaults={
                    "summary": guide["summary"],
                    "order": guide["order"],
                    "is_published": True,
                },
            )
            for item in guide["steps"]:
                ResourceStep.objects.update_or_create(
                    topic=topic,
                    order=item["order"],
                    defaults={
                        **{key: value for key, value in item.items() if key not in ("order",)},
                        "author": "UDM Ministry Team",
                        "is_published": True,
                    },
                )
                step_total += 1

        # The Learn tab's shelves. Each recording is seeded with its teaching
        # text and no link, so the app opens it as a readable page with no play
        # control; staff paste the ministry's YouTube address in the console and
        # the player appears. A shelf with no live recording is hidden entirely.
        recording_total = 0
        for shelf in MEDIA_SHELVES:
            collection, _ = MediaCollection.objects.update_or_create(
                title=shelf["title"],
                defaults={
                    "description": shelf["description"],
                    "order": shelf["order"],
                    "is_published": True,
                },
            )
            for item in shelf["items"]:
                MediaItem.objects.update_or_create(
                    collection=collection,
                    order=item["order"],
                    defaults={
                        **{key: value for key, value in item.items() if key not in ("order",)},
                        "author": "UDM Ministry Team",
                        "is_published": True,
                    },
                )
                recording_total += 1

        self.stdout.write(self.style.SUCCESS(
            "Seeded %s memory verses, one series of %s devotions, %s articles, %s resource guides of %s steps, "
            "%s media shelves of %s recordings."
            % (len(MEMORY_VERSES), len(DEVOTIONALS), len(ARTICLES), len(RESOURCE_TOPICS), step_total,
               len(MEDIA_SHELVES), recording_total)
        ))

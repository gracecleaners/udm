"""Seed starter ministry content so a fresh checkout has something to read.

Scripture quotations are King James Version (public domain). Devotional and
article prose here is written for UDM; replace it with curated ministry content
through the admin console rather than editing this command.
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from content.models import Article, Devotional, FeaturedVerse

VERSES = [
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


class Command(BaseCommand):
    help = "Create starter featured verses, devotionals and articles (idempotent)."

    def add_arguments(self, parser):
        parser.add_argument("--flush-existing", action="store_true", help="Deactivate current featured verses first.")

    @transaction.atomic
    def handle(self, *args, **options):
        if options["flush_existing"]:
            FeaturedVerse.objects.update(is_active=False)

        for reference, text in VERSES:
            FeaturedVerse.objects.get_or_create(
                reference=reference,
                translation_code="kjv",
                defaults={"text": text, "attribution": "King James Version (public domain)", "is_active": True},
            )

        for item in DEVOTIONALS:
            Devotional.objects.update_or_create(
                title=item["title"],
                defaults={**item, "is_published": True},
            )

        for item in ARTICLES:
            Article.objects.update_or_create(
                title=item["title"],
                defaults={**item, "is_published": True},
            )

        self.stdout.write(self.style.SUCCESS(
            "Seeded %s featured verses, %s devotionals, %s articles." % (len(VERSES), len(DEVOTIONALS), len(ARTICLES))
        ))

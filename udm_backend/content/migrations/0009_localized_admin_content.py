from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0008_biblebook_provider_id_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="devotional",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="article",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="featuredverse",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="biblereadingplan",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="biblereadingassignment",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="course",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="coursemodule",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="courselesson",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="lessonquiz",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="quizquestion",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="memoryverse",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="university",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="campus",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="fellowship",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="discipleshipgroup",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
        migrations.AddField(
            model_name="event",
            name="translations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Language-specific text is edited in the translation fields below.",
            ),
        ),
    ]

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [("content", "0020_resourcetopic_pdf")]

    operations = [
        migrations.AddField(
            model_name="resourcetopic",
            name="views",
            field=models.PositiveIntegerField(default=0, editable=False),
        ),
        migrations.AddField(
            model_name="resourcestep",
            name="is_new_believer",
            field=models.BooleanField(
                default=False,
                help_text="Show this step in the app's New Believer section.",
            ),
        ),
    ]

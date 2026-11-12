"""Drop the table the previous migration emptied.

Kept separate from the data move so a deployment can run the copy, check its
memory-verse list, and only then lose the old rows.
"""

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0011_move_featured_verses_into_memory_verses"),
    ]

    operations = [
        migrations.DeleteModel(
            name="FeaturedVerse",
        ),
    ]

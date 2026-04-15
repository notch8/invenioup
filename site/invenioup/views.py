"""Custom views for InvenioUp Demo."""

from flask import Blueprint

#
# Registration
#
def create_blueprint(app):
    """Register blueprint routes on app."""
    blueprint = Blueprint(
        "invenioup",
        __name__,
        template_folder="./templates",
    )

    # Add URL rules
    return blueprint

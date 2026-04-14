# Dockerfile that builds a fully functional image of the InvenioRDM demo.
#
# Fully containerized -- no Python, pipenv, or Node.js needed on the host.
# The CERN base image provides Python 3.12, Node.js, npm, and pipenv.
#
# Build:
#   docker build -t invenioup .
#
# The Pipfile.lock is generated inside the build if not present.

FROM registry.cern.ch/inveniosoftware/almalinux:1 AS web

# Pin less to 4.5.1 to avoid the known 4.6.2 build breakage.
# See: https://github.com/inveniosoftware/invenio-assets (JS dependency roulette)
RUN npm install -g less@4.5.1

COPY site ./site
COPY Pipfile ./
COPY Pipfile.lock* ./
RUN if [ ! -f Pipfile.lock ]; then pipenv lock; fi && \
    pipenv install --deploy --system

COPY ./docker/uwsgi/ ${INVENIO_INSTANCE_PATH}
COPY ./invenio.cfg ${INVENIO_INSTANCE_PATH}
COPY ./templates/ ${INVENIO_INSTANCE_PATH}/templates/
COPY ./app_data/ ${INVENIO_INSTANCE_PATH}/app_data/
COPY ./translations/ ${INVENIO_INSTANCE_PATH}/translations/
COPY ./ .

RUN invenio collect --verbose
RUN invenio webpack create

RUN cp -r ./static/. ${INVENIO_INSTANCE_PATH}/static/ && \
    cp -r ./assets/. ${INVENIO_INSTANCE_PATH}/assets/

RUN invenio webpack install
RUN invenio webpack build

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

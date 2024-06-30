CONFIG_DIR_PATH = "/config"
DASHBOARDS_DIR_PATH = "/dashboards"


def run(
    plan,
    prometheus_url,
    grafana_dashboards_location,
    name="grafana",
    grafana_dashboards_name="Grafana Dashboards in Kurtosis",
    grafana_alerting_template="",
    grafana_alerting_data={},
):
    """Runs provided Grafana dashboards in Kurtosis.

    Args:
        prometheus_url (string): Prometheus endpoint that will populate Grafana dashboard data.
        grafana_dashboards_location (string): Where to find config for Grafana dashboard(s) (usually sitting somewhere in the repo that's importing this package).
        grafana_dashboards_name (string): Name of Grafana Dashboard provider.
        grafana_alerting_template (string, optional): Path to the Grafana alerting file (usually sitting somewhere in the repo that's importing this package).
        grafana_alerting_data (dict[string, string], optional): The data used when templating the grafana_alerting_template.
    """

    # create config files artifacts based on datasource and dashboard providers info
    datasource_config_template = read_file(src="./static-files/datasource.yml.tmpl")
    dashboard_provider_config_template = read_file(
        src="./static-files/dashboard-providers.yml.tmpl"
    )
    grafana_config_files_artifact = plan.render_templates(
        config={
            "datasources/datasource.yml": struct(
                template=datasource_config_template,
                data={"PrometheusURL": prometheus_url},
            ),
            "dashboards/dashboard-providers.yml": struct(
                template=dashboard_provider_config_template,
                data={
                    "DashboardProviderName": grafana_dashboards_name,
                    "DashboardsDirpath": DASHBOARDS_DIR_PATH,
                },
            ),
            "alerting/alerting.yml": struct(
                template=read_file(grafana_alerting_template),
                data=grafana_alerting_data,
            ),
        }
    )

    # grab grafana dashboards from given location and upload them into enclave as a files artifact
    grafana_dashboards_files_artifact = plan.upload_files(
        src=grafana_dashboards_location, name="grafana-dashboards"
    )

    plan.add_service(
        name=name,
        config=ServiceConfig(
            image="grafana/grafana",
            ports={
                "dashboards": PortSpec(
                    number=3000,
                    transport_protocol="TCP",
                    application_protocol="http",
                )
            },
            env_vars={
                "GF_PATHS_PROVISIONING": CONFIG_DIR_PATH,
                "GF_AUTH_ANONYMOUS_ENABLED": "true",
                "GF_AUTH_ANONYMOUS_ORG_ROLE": "Admin",
                "GF_AUTH_ANONYMOUS_ORG_NAME": "Main Org.",
            },
            files={
                CONFIG_DIR_PATH: grafana_config_files_artifact,
                DASHBOARDS_DIR_PATH: grafana_dashboards_files_artifact,
            },
        ),
    )

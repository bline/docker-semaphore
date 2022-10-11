{% set bools = ['EMAIL_ALERT','TELEGRAM_ALERT','SLACK_ALERT','LDAP_ENABLE','LDAP_NEEDTLS'] -%}
{% set dbopts = ['SEMAPHORE_DB_HOST', 'SEMAPHORE_DB_USER', 'SEMAPHORE_DB_PASS', 'SEMAPHORE_DB_NAME'] %}
{% set ints = ['MAX_PARALLEL _TASKS'] -%}
{
  {% if SEMAPHORE_DIALECT is defined %}"dialect": {{ SEMAPHORE_DIALECT|tojson }},{% endif %}
  "bolt": {
  {% if SEMAPHORE_DIALECT is defined and SEMAPHORE_DIALECT == 'bolt' and SEMAPHORE_DB_HOST is defined -%}
    "host": {{ SEMAPHORE_DB_HOST|tojson }}
  {% endif -%}
  },
  "postgres": {
  {% if SEMAPHORE_DIALECT is defined and SEMAPHORE_DIALECT == 'postgres' -%}
    {% for key, value in environment('SEMAPHORE_DB_') -%}
      {{ key|lower()|tojson }}: {{ value|tojson }}{{ ',' if not loop.last }}
    {% endfor -%}
  {% endif -%}
  },
  "mysql": {
  {% if SEMAPHORE_DIALECT is defined and SEMAPHORE_DIALECT == 'mysql' -%}
    {% for key, value in environment('SEMAPHORE_DB_') -%}
      {{ key|lower()|tojson }}: {{ value|tojson }}{{ ',' if not loop.last }}
    {% endfor -%}
  {% endif -%}
  },
  "ldap_mappings": {
  {% for key, value in environment('SEMAPHORE_LDAP_MAPPINGS_') -%}
    {{ key|lower()|tojson }}: {{ value|tojson }}{{ ',' if not loop.last }}
  {% endfor -%}
  }
  {% for key, value in environment('SEMAPHORE_') -%}
  {% if not key.startswith('DB_') and not key.startswith('LDAP_MAPPINGS_') -%}
  , {{ key|lower()|tojson }}: {% if key in ints %}{{ value|default(0) }}{% elif key in bools -%}{% if 'yes' in (value|lower()) or 'true' in (value|lower()) %}true{% else %}false{% endif %}{% else %}{{ value|tojson }}{% endif %}{% endif %}
{% endfor -%}
}

"""
Simple welcome view for root URL.
"""
from django.http import JsonResponse


def api_root(request):
    """
    GET /
    Root endpoint showing API info.
    """
    return JsonResponse({
        'message': 'Evacuation System API',
        'version': '1.0',
        'status': 'running',
        'endpoints': {
            'admin': '/admin/',
            'api_docs': 'See COMPLETE_SYSTEM_DOCUMENTATION.md',
            'auth': {
                'login': '/api/auth/login/',
                'register': '/api/auth/register/',
                'profile': '/api/auth/profile/',
            },
            'hazards': {
                'submit': '/api/report-hazard/',
                'my_reports': '/api/my-reports/',
                'verified': '/api/verified-hazards/',
            },
            'centers': '/api/evacuation-centers/',
            'notifications': '/api/notifications/',
        },
        'test_credentials': {
            'note': 'Credentials are managed via environment variables. See deployment docs.',
        }
    })

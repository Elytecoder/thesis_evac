"""Serializers for evacuation centers."""
from rest_framework import serializers
from .models import EvacuationCenter


class EvacuationCenterSerializer(serializers.ModelSerializer):
    class Meta:
        model = EvacuationCenter
        fields = ('id', 'name', 'latitude', 'longitude', 'address', 'description')

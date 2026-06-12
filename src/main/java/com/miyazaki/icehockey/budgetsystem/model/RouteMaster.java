package com.miyazaki.icehockey.budgetsystem.model;

public class RouteMaster {
    private Integer id;
    private String departure;
    private String destination;
    private Integer distanceKm;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    
    public String getDeparture() { return departure; }
    public void setDeparture(String departure) { this.departure = departure; }
    
    public String getDestination() { return destination; }
    public void setDestination(String destination) { this.destination = destination; }
    
    public Integer getDistanceKm() { return distanceKm; }
    public void setDistanceKm(Integer distanceKm) { this.distanceKm = distanceKm; }
}

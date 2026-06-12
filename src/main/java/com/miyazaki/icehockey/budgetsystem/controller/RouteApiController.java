package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.RouteMasterMapper;
import com.miyazaki.icehockey.budgetsystem.model.RouteMaster;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/routes")
public class RouteApiController {

    @Autowired
    private RouteMasterMapper routeMasterMapper;

    @GetMapping("/distance")
    public ResponseEntity<?> getDistance(@RequestParam("departure") String departure, @RequestParam("destination") String destination) {
        RouteMaster route = routeMasterMapper.findByRoute(departure, destination);
        if (route != null) {
            Map<String, Object> response = new HashMap<>();
            response.put("distanceKm", route.getDistanceKm());
            return ResponseEntity.ok(response);
        }
        return ResponseEntity.notFound().build();
    }
}

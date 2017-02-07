// Simple Tracker Angular JS app
(function(w, d) {
    
    // Project prototype
    function Project(id, name) {
        this.id = id;
        this.name = name;
        this.categories = [];
    }
    
    // Load from JSON
    Project.load = function(json) {
        var newProj = new Project(json.id, json.name);
        
        for(var i in json.categories) {
            var catInfo = json.categories[i];
            var cat = new Category(catInfo.id, catInfo.name);
            cat.type = catInfo.type;
            cat.countsByStatus = [
                { id: 0, name: catInfo.statuses[0] },
                { id: 2, name: catInfo.statuses[1] }
            ];
            newProj.categories.push(cat);
        }
        
        return newProj;
    };
    
    // Category prototype
    function Category(id, name) {
        this.id = id;
        this.name = name;
        this.type = null;
        
        this.countsByStatus = null;
    }
    
    // Item prototype
    function Ticket(id, title) {
        this.id = id;
        this.title = title;
        this.text = title;
        this.status = 0;
        this.progress = 0;
        this.done = false;
        this.catId = 0;
        this.tags = [];
        
        this._step = 20;
    }
    
    Ticket.load = function(json) {
        var newTicket = new Ticket(json.id, json.title);
        newTicket.catId = json.category_id;
        newTicket.text = json.text;
        newTicket.priority = json.priority;
        newTicket.progress = json.progress;
        newTicket.done = newTicket.progress == 100;
        newTicket.status = json.status;
        
        if(json.tags != null) {
            newTicket.tags = json.tags;
        }
        
        return newTicket;
    };
    
    Ticket.prototype.dump = function() {
        return {
            id: this.id,
            category_id: this.catId,
            text: this.text,
            priority: this.priority,
            status: this.status,
            progress: this.progress,
            tags: this.tags
        };
    };
    
    Ticket.prototype.increaseProgress = function() {
        var newProgress = this.progress + this._step;
        this.progress = newProgress < 100 ? newProgress : 100;
        if(this.progress == 100) {
            this.done = true;
        }
    };
    
    Ticket.prototype.decreaseProgress = function() {
        var newProgress = this.progress - this._step;
        this.progress = newProgress >= 0 ? newProgress : 0;
        
        this.done = false;
    };
    
    // Last user action prototype
    function Action(type, ts, userId) {
        this.type = type;
        var tzInfoStart = ts.lastIndexOf(' ');
        // DateTime without timezone info
        this.timestamp = new Date(ts.substr(0, tzInfoStart));
        this.userId = userId;
        this.itemId = null;
        this.itemTitle = null;
        this.description = null;
        this.data = null;
    }
    
    Action.prototype.getProgress = function() {
        return this.data.length > 0 ? this.data[0] + '%' : null;
    };
    
    Action.prototype.getDateTime = function() {
        // Get date and time without seconds
        var locTsString = this.timestamp.toLocaleString();
        var tsWoSeconds = locTsString.substr(0, locTsString.length - 3);
        return tsWoSeconds;
    };
    
    Action.load = function(json) {
        var newAction = new Action(json.type, json.ts,  json.user_id);
        newAction.itemId = json.item_id;
        newAction.itemTitle = json.item_title;
        newAction.description = json.description;
        newAction.data = json.data;
        
        return newAction;
    };

    // Application
    const app = angular.module('tracker', []);
    
    app.service('provider', function($http) {
        
        const PROJECTS_URL = '/projects';
        const TICKETS_URL = '/tickets';
        const PROGRESS_URL = '/ticket_progress';
        const CONFIRM_URL = '/confirm_ticket';
        const SAVE_TICKET_URL = '/save_ticket';
        const REMOVE_TICKET_URL = '/remove_ticket';
        const LAST_ACTIONS_URL = '/last_actions';
        
        // Get all projects info
        this.getProjects = function(callback) {
            function projectsReceived(response) {
                var projects = response.data.map(function(projJson) {
                    return Project.load(projJson);
                });
                
                callback(projects);
            }
            
            $http.get(PROJECTS_URL).then(projectsReceived);
        };
        
        // Get all tickets in current category with status
        this.getTickets = function(catId, status, callback) {
            function ticketsReceived(response) {
                var items = response.data.map(function(ticketJson) {
                    return Ticket.load(ticketJson);
                });
                
                callback(items);
            }
            
            var url = TICKETS_URL + '/' + catId + '/' + status;
            $http.get(url).then(ticketsReceived);
        };
        
        // Post item progress to server
        this.postProgress = function(item) {
            var data = { id: item.id, progress: item.progress };
            $http.post(PROGRESS_URL, data);
        };
        
        // Confirm that ticket is done
        this.confirmItemDone = function(item, callback) {
            var data = { id: item.id };
            $http.post(CONFIRM_URL, data).then(callback);
        };
        
        // Save ticket data
        this.saveItem = function(item, callback) {
            var saveMethod = item.id != 0 ? $http.put : $http.post;
            saveMethod(SAVE_TICKET_URL, item.dump()).then(callback);
        };
        
        // Remove ticket data
        this.removeItem = function(item, callback) {
            var url = REMOVE_TICKET_URL + '/' + item.id;
            $http.delete(url).then(callback);
        };
        
        // Get last users' actions list
        this.getLastActions = function(callback) {
            function actionsReceived(response) {
                var actions = response.data.map(function(actionJson) {
                    return Action.load(actionJson);
                });
                
                callback(actions);
            }
            
            $http.get(LAST_ACTIONS_URL).then(actionsReceived);
        };
    });
    
    // Global initialization
    app.run(function($rootScope, $timeout) {        
        // Do action after animation finished
        function afterAnim(callback) {
            const ANIM_TIME = 300;
            
            menuAnimPlaying = true;
            $timeout(function() {
                callback();
                menuAnimPlaying = false;
            }, ANIM_TIME);
        }
        
        // Close menu on click on rest area
        function closeMenu(e) {
            var elem = e.target;
            while(elem != null) {
                if(elem.tagName.toLowerCase() == 'aside') {
                    return;
                }
                elem = elem.parentElement;
            }
            
            // Clicked outside of menu
            $timeout($rootScope.toggleSideMenu, 0);
        }
        
        const CSS_CLASS_SHOW = 'in';
        const CSS_CLASS_HIDE = 'out';
        
        
        // Menu show options
        $rootScope.menuShown = false;
        $rootScope.menuAnimClass = '';
        
        // Default title
        $rootScope.title = null;
        $rootScope.subTitle = null;
        
        // Default view mode
        $rootScope.mode = 'dashboard';
        
        var menuAnimPlaying = false;
        
        // Control side menu
        $rootScope.toggleSideMenu = function() {
            if(menuAnimPlaying) {
                return;
            }
            
            if($rootScope.menuShown) {
                $rootScope.menuAnimClass = CSS_CLASS_HIDE;
                // Delay menu disappearing
                afterAnim(function() {
                    $rootScope.menuShown = false;
                    d.removeEventListener('click', closeMenu);
                });
            } else {
                $rootScope.menuAnimClass = CSS_CLASS_SHOW;
                $rootScope.menuShown = true;
                // Delay class reset
                afterAnim(function() {
                    $rootScope.menuAnimClass = '';
                    d.addEventListener('click', closeMenu);
                });
            }
        };
        
        // Currently selected category and status
        $rootScope.nav = {
            categoryId: null,
            statusId: null
        };
        
        // Projects loaded callback
        $rootScope.onviewchanged = null;
        
        $rootScope.onitemselected = null;
        $rootScope.onnewitem = null;
        $rootScope.ondashboard = null;
    });
    
    // Menu controller
    app.controller('menu', function($scope, provider) {
        var root = $scope.$parent;
            
        // Request tickets from server
        function requestTickets() {
            root.title = $scope.project.name;
            root.subTitle = $scope.category.name + ' - ' + $scope.status.name;
            root.onviewchanged($scope.category.id, $scope.status.id);
            
            // Update navigation info
            root.nav.categoryId = $scope.category.id;
            root.nav.statusId = $scope.status.id;
        }
        
        // Set category and status for new project
        function setInitialCategoryAndStatus() {
            $scope.category = $scope.project.categories[0];
            $scope.status = $scope.category.countsByStatus[0];
            requestTickets();
        }
        
        // Got projects data
        function projectsLoaded(projects) {
            $scope.projects = projects;
            
            // Selected project change callback
            $scope.$watch('project', function() {
                if($scope.project != null) {
                    setInitialCategoryAndStatus();
                }
            });
        }
        
        // Data model elements
        $scope.projects = null;
        $scope.project = null;
        $scope.category = null;
        $scope.status = null;
        
        // Load projects info
        provider.getProjects(projectsLoaded);
        
        // Switch to dashoard view
        $scope.showDashboard = function() {
            root.mode = 'dashboard';
            root.ondashboard();
        };
        
        $scope.changeCategoryView = function(cat) {
            $scope.category = cat;
            $scope.status = cat.countsByStatus[0];
            requestTickets();
            $scope.$applyAsync();
        };
        
        $scope.changeStatusView = function(stat) {
            $scope.status = stat;
            requestTickets();
            $scope.$applyAsync();
        };
        
        // Active class
        $scope.isActive = function(item, itemType) {
            if(root.mode == 'dashboard')
                return false;
            
            if(itemType == 'c') {
                return $scope.category == item ? 'active' : null;
            } else if(itemType == 's') {
                return $scope.status == item ? 'active' : null;
            }
        };
        
        $scope.isDashboardShown = function() {
            return root.mode == 'dashboard' ? 'active' : null;
        };
    });
    
    // List controller
    app.controller('list', function($scope, provider) {
        const STATUS_DONE = 2;
        
        var root = $scope.$parent;
        
        // Loading state
        $scope.loading = true;
        $scope.loadingBannerShown = true;
        
        $scope.selectedItem = null;
        $scope.items = [];
        
        function ticketsLoaded(items) {
            $scope.loading = false;
            $scope.loadingBannerShown = false;
            root.mode = 'list';
            $scope.items = items;
            $scope.applyAsync();
        }
        
        // Show loading banner after small timeout after loading
        function delayLoadingBanner() {
            window.setTimeout(function() {
                if($scope.loading) {
                    loadingBannerShown = true;
                }
            }, 50);
        }
                
        // Load tickets after projects loaded
        root.onviewchanged = function(catId, statId) {
            $scope.loading = true;
            delayLoadingBanner();
            provider.getTickets(catId, statId, ticketsLoaded);
        };
        
        $scope.isActiveTicketsView = function() {
            return root.nav.statusId != STATUS_DONE;
        };
        
        $scope.newItem = function() {
            root.mode = 'item';
            root.onnewitem();
        };
        
        $scope.openItem = function(item) {
            root.mode = 'item';
            root.onitemselected(item);
        };
        
        $scope.selectItem = function(item) {
            if($scope.selectedItem != item) {
                $scope.selectedItem = item;
            } else {
                $scope.selectedItem = null;
            }
        };
        
        $scope.changeProgress = function(item, delta) {
            var oldProgress = item.progress;
            
            if(delta > 0)
                item.increaseProgress();
            else if(delta < 0)
                item.decreaseProgress();
            
            // Post changed progress
            if(item.progress != oldProgress) {
                provider.postProgress(item);
            }
        };
        
        // Confirm item completion by manager
        $scope.confirmDone = function(item) {
            provider.confirmItemDone(item, function() {
                root.onviewchanged(root.nav.categoryId, root.nav.statusId);
            });
        };
        
        $scope.hasItems = function() {
            return $scope.items.length > 0;
        };
        
        $scope.itemDescription = function(item) {
            return item.replace("\n", " ->");
        };
        
        $scope.tagText = function(tag) {
            return tag.indexOf('#') == 1 ? tag.substr(2) : tag;
        };
        
        $scope.tagClass = function(tag) {
            if(tag.indexOf('#') == 1) {
                // Decorated
                var colorClass = tag.charAt(0);
                return colorClass;
            } else {
                // Undecorated
                return null;
            }  
        };
        
        // Set class for disable button on loading
        $scope.disableOnLoad = function() {
            return $scope.loading ? 'disabled' : null;
        };
        
        // Set class for selected item
        $scope.selectedClass = function(item) {
            return $scope.selectedItem == item ? 'selected' : null;
        };
        
        // ???
        $scope.progressView = {
            style: function(item) {
                var color = item.progress > 70 ? '#aaffaa' : '#ddff88';
                return {
                    'width': item.progress + '%',
                    'border-top-color': color
                };
            },
            priority: function(item) {
                var addClasses = [' low', '', ' high'];
                return 'sign' + addClasses[item.priority];
            },
            type: function(item) {
                if(item.done) {
                    return 'done';
                } else if(item.progress > 0) {
                    return 'in-progress';
                } else {
                    return 'new';
                }
            }
        };
    });
    
    // Item view controller
    app.controller('item', function($scope, provider) {
        var root = $scope.$parent;
        
        // Return back to list
        function returnToList() {
            root.onviewchanged(root.nav.categoryId, root.nav.statusId);
            root.mode = 'list';
        }

        $scope.editing = false;
        $scope.editingItem = null;
        
        $scope.itemTagsInline = function(newTags) {
            if($scope.editingItem == null)
                return '';
            
            if(arguments.length == 0) {
                // Getter
                return $scope.editingItem.tags.join(', ');
            } else {
                // Setter
                var splittedTags = newTags.split(/\s*,\s*/);
                if(splittedTags.length == 1 && splittedTags[0] == '') {
                    splittedTags = [];
                }
                $scope.editingItem.tags = splittedTags;
            }
        };

        // Save ticket
        $scope.saveItem = function() {
            if($scope.editingItem.text.trim().length > 0) {
                provider.saveItem($scope.editingItem, returnToList);
            }
        };
        
        // Cancel ticket editing
        $scope.closeItem = function() {
            root.mode = 'list';
        };
        
        // Remove current ticket
        $scope.removeItem = function() {
            provider.removeItem($scope.editingItem, returnToList);
        };
        
        // Set editing item priority
        $scope.setPriority = function(priority) {
            $scope.editingItem.priority = priority;
            $scope.$applyAsync();
        };
        
        // Return active CSS class if priorities matches
        $scope.activeIfPriority = function(priority) {
            if($scope.editingItem != null) {
                var itemPriority = $scope.editingItem.priority;
                return itemPriority == priority ? 'active' : null;
            } else {
                return null;
            }
        };
        
        // New ticket creating
        root.onnewitem = function() {
            var newItem = new Ticket(0, '');
            newItem.priority = 1;
            newItem.catId = root.nav.categoryId;
            $scope.editingItem = newItem;
            $scope.$applyAsync();
            $scope.editing = false;
        };

        // Ticket selected
        root.onitemselected = function(item) {
            $scope.editingItem = angular.copy(item);
            $scope.$applyAsync();
            $scope.editing = true;
        };
    });
    
    // Dashboard controller
    app.controller('dashboard', function($scope, provider) {
        // Last actions list loaded
        function actionsLoaded(actions) {
            $scope.actions = actions;
            $scope.applyAsync();
        };
        
        var root = $scope.$parent;
        
        // Last actions list
        $scope.actions = null;
        
        // Get path to user picture from action
        $scope.getImgPath = function(action) {
            return '/tiles/' + action.userId + '.jpg';
        };
        
        // Dashboard view callback
        root.ondashboard = function() {
            root.title = root.subTitle = null;
            provider.getLastActions(actionsLoaded);
        };
        
        root.ondashboard();
    });
    
    // Handle image not found error
    w.setImgStub = function(imageElem) {
        imageElem.src = '/tiles/default.jpg';
    };
})(window, document);

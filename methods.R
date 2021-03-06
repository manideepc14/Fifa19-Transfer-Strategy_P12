rm(list = ls(all = T))
require(caret)
require(rpart)
require(ggplot2)
require(reshape2)
require(data.table)
require(philentropy)
require(plyr)
require(utils)
source('./fifaPositionMethods.R')

calculate_distance_matrix <- function(train_matrix, test_matrix, method_name){
  distance_matrix = matrix(0L, nrow = nrow(test_matrix), ncol = nrow(train_matrix))
  if(method_name %in% c("calculate_euclidean", "calculate_cosine", "calculate_manhattan")){
    for(i in seq(1, nrow(test_matrix))){
      print(i)
      for(j in seq(1, nrow(train_matrix))){
        poslisttest<-return_list_for_position(test_matrix[i,'Position'])
        
        distance_matrix[i,j] <- do.call(method_name, list(unlist(test_matrix[i,c(names(poslisttest))]), unlist(train_matrix[j,c(names(poslisttest))]), unlist(poslisttest)))
      }
    }
  }else if(method_name == "calculate_chebyshev"){

    distance_matrix <- calculate_chebyshev(data_matrix)
  }
  return(distance_matrix)
}

calculate_euclidean <- function(p, q, poslist) {
  
  return (sqrt(sum((p - q) ^ 2/poslist)))
}

calculate_cosine <- function(p, q) {
  return (sum(p*q)/(sqrt(sum(p ^ 2)) * sqrt(sum(q ^ 2))))
}

calculate_manhattan <- function(p, q) {
  return (sum(abs(p-q)))
}

calculate_chebyshev <- function(data_matrix){
  return (distance(data_matrix, method = "chebyshev"))
}

knn_classifier <- function(x_train, y_train, x_test, distance_method, k){
  distance_matrix <- calculate_distance_matrix(x_train,x_test, distance_method)
  result<- vector()
  
  for(i in seq(1, nrow(distance_matrix))){
    vec <- vector()
    temp<-distance_matrix[i,]
    if(distance_method %in% c("calculate_euclidean", "calculate_chebyshev", "calculate_manhattan")){
      vec<-(sort(temp, index.return=TRUE)$ix)[1:k]
    }
    else if(distance_method=='calculate_cosine'){
      vec<-(sort(temp, index.return=TRUE,decreasing=TRUE)$ix)[1:k]
    }
    vec<-y_train[vec]
    result[i]<-mean(vec)
  }
  print(result)
  return(result)
}

knn_classifier_confidence <- function(x_train, y_train, x_test, distance_method='calculate_cosine', k){
  distance_matrix <- calculate_distance_matrix(x_train,x_test, distance_method)
  result<- vector()
  for(i in seq(1, nrow(distance_matrix))){
    vec <- vector()
    temp<-distance_matrix[i,]
    ordered<-(sort(temp, index.return=TRUE,decreasing=TRUE))[1:k]
    confidence<-sum(ordered$x[1:k])
    for(j in seq(1, k)){
      if(is.na(vec[toString(y_train[ordered$ix[j]])])){
        vec[toString(y_train[ordered$ix[j]])]<-0
      }
      vec[toString(y_train[ordered$ix[j]])]<-vec[toString(y_train[ordered$ix[j]])]+ordered$x[j]
    }
    vec<-vec/confidence
    result[i]<-strtoi(names(sort(vec,decreasing=TRUE)[1]))
  }
  return(as.factor(result))
  
}

dtree <- function(x_train, y_train, x_test){
  set.seed(123)
  x_train[,ncol(x_train)+1]<-y_train
  colnames(x_train)[ncol(x_train)] <- "Class"
  tree <- rpart(Class~.,
                data=x_train,
                method = "class",
                parms=list(split='gini'))
  plot(tree)
  text(tree)
  return(rpart_predict <- predict(tree,x_test,type="class"))
  
}


dtree_cv <- function(x_train, y_train, x_test, n_folds){
  set.seed(123)
  x_train[,ncol(x_train)+1]<-y_train
  colnames(x_train)[ncol(x_train)] <- "Class"
  
  train_control<- trainControl(method="cv", number=n_folds, savePredictions = TRUE)
  
  model<- train(Class~., data=x_train, trControl=train_control, method="rpart")
  
  cv_predict<- predict(model,x_test)
  
  return(cv_predict)
  
}

getAgeBracket<-function(normalized_age){
  if(normalized_age<= 0.25){
    return(0.25)
  }
  else if(normalized_age<= 0.5 && normalized_age>0.25){
    return(0.5)
  }
  else if(normalized_age<= 0.75 && normalized_age>0.5){
    return(0.75)
  }
  else{
    return(1)
  }
}

regression <- function(k){
  FullData <- as.data.frame(read.csv("./data_normalize.csv",header=TRUE,encoding = "UTF-8"))
  #M<-(cor(FullData[,c(4,14:47)])[,1, drop=FALSE])
  #corrplot(M, method="number")
  #print(nrow(FullData))
  smp_size <- floor(0.8 * nrow(FullData))
  
  ## set the seed to make your partition reproducible
  set.seed(123)
  train_ind <- sample(seq_len(nrow(FullData)), size = smp_size)
  
  train.data <- FullData[train_ind, ]
  test.data <- FullData[-train_ind, ]
  
  # Build the model
  #model <- lm(Value ~ CalculatedOverall, data = train.data)
  # Make predictions
  #predictions <- model %>% predict(test.data)
  #print (predictions)
  # Model performance
  #data.frame(
  #  RMSE = RMSE(predictions, test.data$Value),
  #  R2 = R2(predictions, test.data$Value)
  #)
  
  #ggplot(train.data, aes(CalculatedOverall, Value) ) +
  #  geom_point() +
  #  stat_smooth(method = lm, formula = y ~ x,colour="red")
  modelDict <- vector(mode="list", length=40)
  count<-0
  v<- vector()
  ageBrackets<- c(0.25,0.5,0.75,1)
  positions<-c("GK","CB","B","WB","DM","AM","M","W","F","S")
  for(age in ageBrackets){
    for(position in positions){
      temp<-train.data[train.data$Age <=age & train.data$Age> (age -0.38), ] 
      temp<-temp[temp$Position %in%  getPositions(position), ] 
      count<-count + 1
      v<- c(v,paste(position,"-",toString(age)))
      modelDict[[count]] <- lm(Value ~ poly(CalculatedOverall, 4, raw = TRUE), data = temp);
    }
  }
  names(modelDict)<-v
  predictions<-vector()
  
  for(i in seq(1, nrow(test.data))){
    predictions<-c(predictions,modelDict[[paste(getPositionClass(test.data[i,"Position"]),"-",toString(getAgeBracket(test.data[i,"Age"])))]] %>% predict(test.data[i,]))
  }
  #print(predictions)
  # Model performance
  data.frame(
    RMSE = RMSE(predictions, test.data$Value),
    R2 = R2(predictions, test.data$Value)
  )
  
  ggplot(train.data, aes(CalculatedOverall, Value) ) +
    geom_point() +
    stat_smooth(method = lm, formula = y ~ poly(x, 5, raw = TRUE),colour="red")
}

calculate_accuracy <- function(y_pred, y_true){
  print(as.table(setNames(y_pred, y_true)))
  return(as.table(setNames(y_pred, y_true)))
}

